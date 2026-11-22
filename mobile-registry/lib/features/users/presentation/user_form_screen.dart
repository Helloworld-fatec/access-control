import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_message.dart';
import '../data/face_camera.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';
import 'user_data_fields.dart';
import 'user_form_model.dart';
import 'user_photo.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    this.userId,
    required this.repository,
    required this.capturePhoto,
    required this.onChanged,
  });

  final String? userId;
  final UsersRepository repository;
  final FacePhotoCapture capturePhoto;
  final Future<void> Function() onChanged;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _model = UserFormModel();
  UserSummary? _user;
  Uint8List? _photo;
  Future<Uint8List?> Function()? _loadSavedPhoto;
  String? _nfcStatus;
  NfcEnrollment? _nfcEnrollment;
  Timer? _nfcPoll;
  String? _notice;
  String? _faceError;
  String? _nfcError;
  String? _loadError;
  bool _hasFace = false;
  bool _consent = false;
  bool _busy = false;
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final id = widget.userId;
    if (id != null) _load(id);
  }

  @override
  void dispose() {
    _nfcPoll?.cancel();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final detail = await widget.repository.get(id);
      if (!mounted) return;
      setState(() {
        _user = detail.user;
        _model.fill(detail.user);
        _hasFace = detail.hasFace;
        _loadSavedPhoto = detail.hasPhoto ? () => widget.repository.getPhoto(id) : null;
        _nfcStatus = detail.nfcCredentialStatus;
        _nfcEnrollment = detail.nfcEnrollment;
      });
      _scheduleNfcPoll(id);
    } catch (error) {
      if (mounted) setState(() => _loadError = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _faceError = null;
    });
    try {
      final photo = await widget.capturePhoto();
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _consent = false;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _faceError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _faceError = 'Não foi possível abrir a câmera.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkNfc(UsersRepository repository, String id) async {
    try {
      final enrollment = await repository.startNfcEnrollment(id);
      if (!mounted) return;
      setState(() {
        _nfcEnrollment = enrollment;
        _nfcStatus = 'PENDING';
      });
      _scheduleNfcPoll(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _nfcError = userMessageFor(error));
    }
  }

  void _scheduleNfcPoll(String userId) {
    _nfcPoll?.cancel();
    final request = _nfcEnrollment;
    if (request == null || request.status != 'PENDING') return;
    _nfcPoll = Timer(const Duration(seconds: 2), () async {
      try {
        final result = await widget.repository.getNfcEnrollment(userId, request.id);
        if (!mounted || _nfcEnrollment?.id != request.id) return;
        setState(() {
          _nfcEnrollment = result;
          if (result.status == 'WRITTEN') _nfcStatus = 'ACTIVE';
          _nfcError = null;
        });
        if (result.status == 'WRITTEN') unawaited(widget.onChanged());
      } catch (error) {
        if (!mounted || _nfcEnrollment?.id != request.id) return;
        setState(() => _nfcError = userMessageFor(error));
      }
      _scheduleNfcPoll(userId);
    });
  }

  Future<void> _saveFace(UsersRepository repository, String id) async {
    final photo = _photo;
    if (photo == null || !_consent) return;
    try {
      final hasPhoto = await repository.saveFace(id, photo);
      if (!mounted) return;
      setState(() {
        _hasFace = true;
        if (hasPhoto) _loadSavedPhoto = () async => photo;
        _photo = null;
        _consent = false;
      });
      if (hasPhoto) unawaited(widget.onChanged());
    } catch (error) {
      if (!mounted) return;
      final api = ApiException.from(error);
      setState(() {
        _faceError = switch (api.code) {
          'NO_FACE' => 'Nenhum rosto foi encontrado. Tire outra foto.',
          'MULTIPLE_FACES' => 'A foto deve conter apenas um rosto.',
          'CORRUPT_IMAGE' ||
          'UNSUPPORTED_IMAGE_TYPE' =>
            'A foto precisa ser um JPEG válido. Tire outra foto.',
          'IMAGE_DIMENSIONS_TOO_LARGE' =>
            'A foto excede o limite de dimensões.',
          _ => api.message,
        };
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_model.formKey.currentState!.validate()) return;
    if (_photo != null && !_consent) {
      setState(
          () => _faceError = 'Confirme o consentimento ou descarte a foto.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notice = null;
      _faceError = null;
      _nfcError = null;
    });
    final repository = widget.repository;
    try {
      var user = _user;
      final created = user == null;
      try {
        if (user == null) {
          user = await repository.create(_model.toNewUser());
        } else {
          final changes = _model.changesFrom(user);
          if (changes.isNotEmpty) {
            user = await repository.update(user.id, changes);
          }
        }
      } catch (error) {
        if (mounted) {
          final result = _model.applyApiError(ApiException.from(error));
          _model.formKey.currentState?.validate();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dados do usuário: ${result.message}')),
          );
        }
        return;
      }
      if (!mounted) return;
      final savedUser = user;
      setState(() {
        _user = savedUser;
        _model.password.clear();
        _model.serverErrors.clear();
        _notice = created ? 'Usuário criado.' : 'Dados do usuário salvos.';
      });
      unawaited(widget.onChanged());
      if (created) await _linkNfc(repository, savedUser.id);
      if (mounted) await _saveFace(repository, savedUser.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryNfc() async {
    setState(() {
      _busy = true;
      _nfcError = null;
    });
    try {
      await _linkNfc(widget.repository, _user!.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryFace() async {
    setState(() {
      _busy = true;
      _faceError = null;
    });
    try {
      await _saveFace(widget.repository, _user!.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Excluir usuário?',
      message: 'O cadastro e as credenciais deste usuário serão excluídos.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    try {
      await widget.repository.delete(_user!.id);
      if (!mounted) return;
      unawaited(widget.onChanged());
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exclusão: ${userMessageFor(error)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _user != null || widget.userId != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar:
            AppBar(title: Text(editing ? 'Editar usuário' : 'Novo usuário')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusMessage(
                              kind: StatusKind.error, message: _loadError!),
                          TextButton(
                            onPressed: () => _load(widget.userId!),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : _form(editing),
        ),
      ),
    );
  }

  Widget _form(bool editing) {
    final photo = _photo;
    final loadSavedPhoto = _loadSavedPhoto;
    return Form(
      key: _model.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice case final String message)
              StatusMessage(kind: StatusKind.success, message: message),
            UserDataFields(
              model: _model,
              isEdit: editing,
              readOnly: _busy,
              showPassword: _showPassword,
              onShowPasswordChanged: (value) =>
                  setState(() => _showPassword = value),
              original: _user,
            ),
            const Divider(),
            Text(_hasFace ? 'Rosto cadastrado' : 'Rosto sem cadastro'),
            if (editing && photo == null)
              Align(
                alignment: Alignment.centerLeft,
                child: loadSavedPhoto == null
                    ? const _PhotoPlaceholder()
                    : UserPhoto(
                        key: ObjectKey(loadSavedPhoto),
                        load: loadSavedPhoto,
                        placeholder: const _PhotoPlaceholder(),
                        height: 160,
                        semanticLabel: 'Foto cadastrada',
                      ),
              ),
            if (photo != null) ...[
              Image.memory(photo,
                  height: 160,
                  fit: BoxFit.contain,
                  semanticLabel: 'Prévia da foto'),
              CheckboxListTile(
                value: _consent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _consent = value ?? false),
                title: const Text('O usuário consentiu com o cadastro facial'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _photo = null;
                          _faceError = null;
                          _consent = false;
                        }),
                child: const Text('Descartar foto'),
              ),
            ],
            if (_faceError case final String message)
              StatusMessage(kind: StatusKind.error, message: 'Foto: $message'),
            if (_user != null &&
                photo != null &&
                _consent &&
                _faceError != null)
              TextButton(
                onPressed: _busy ? null : _retryFace,
                child: const Text('Tentar foto novamente'),
              ),
            AppSecondaryButton(
              label: photo == null ? 'Tirar foto' : 'Refazer foto',
              icon: Icons.camera_alt,
              onPressed: _busy ? null : _capture,
            ),
            const Divider(),
            Text(switch (_nfcEnrollment?.status) {
              'PENDING' => 'Aproxime a tag do ESP32 para gravar.',
              'WRITTEN' when _nfcStatus == 'ACTIVE' =>
                'Gravação NFC confirmada pelo ESP32.',
              'EXPIRED' => 'O prazo de gravação NFC terminou.',
              'FAILED' => switch (_nfcEnrollment?.reason) {
                  'TAG_CONFLICT' => 'Esta tag já está cadastrada.',
                  'UID_MISMATCH' => 'A tag aproximada tem outro UID.',
                  'READBACK_MISMATCH' => 'O código relido diverge do enviado.',
                  _ => 'A gravação NFC falhou.',
                },
              _ when _nfcStatus == 'ACTIVE' => 'Tag NFC ativa.',
              _ when editing => 'Nenhuma gravação NFC em andamento.',
              _ => 'A gravação NFC será solicitada depois de salvar.',
            }),
            if (_nfcError case final String message)
              StatusMessage(kind: StatusKind.error, message: 'NFC: $message'),
            if (_user != null &&
                _nfcStatus != 'ACTIVE' &&
                _nfcEnrollment?.status != 'PENDING')
              TextButton(
                onPressed: _busy ? null : _retryNfc,
                child: Text(_nfcError != null ||
                        _nfcEnrollment?.status == 'FAILED' ||
                        _nfcEnrollment?.status == 'EXPIRED'
                    ? 'Tentar NFC novamente'
                    : 'Gravar tag NFC'),
              ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Salvar usuário',
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            if (_user != null)
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text('Excluir usuário'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const CircleAvatar(
        radius: 32,
        child: Icon(Icons.person_outline, semanticLabel: 'Foto indisponível'),
      );
}
