import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_logo.dart';
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

enum _PhotoChoice { use, retake }

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
  final _uid = TextEditingController();
  UserSummary? _user;
  Uint8List? _photo;
  Future<Uint8List?> Function()? _loadSavedPhoto;
  List<NfcTag> _tags = [];
  String? _notice;
  String? _faceError;
  String? _nfcError;
  String? _nfcNotice;
  String? _loadError;
  bool _hasFace = false;
  bool _consent = false;
  bool _working = false;
  bool _capturingPhoto = false;
  bool get _busy => _working || _capturingPhoto;
  bool _uploadingFace = false;
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
    _uid.dispose();
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
        _tags = detail.nfcTags;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _capturingPhoto = true);
    try {
      while (mounted) {
        final photo = await widget.capturePhoto();
        if (!mounted || photo == null) return;
        final choice = await _previewPhoto(photo);
        if (!mounted || choice == null) return;
        if (choice == _PhotoChoice.retake) continue;
        setState(() {
          _photo = photo;
          _consent = false;
          _faceError = null;
        });
        return;
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _faceError = error.message);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _faceError = switch (error.code) {
            'camera_access_denied' =>
              'Permita o acesso à câmera nas configurações do celular.',
            'camera_access_restricted' =>
              'O acesso à câmera está restrito neste celular.',
            _ => 'Não foi possível abrir a câmera.',
          });
    } catch (_) {
      if (mounted) {
        setState(() => _faceError = 'Não foi possível abrir a câmera.');
      }
    } finally {
      if (mounted) setState(() => _capturingPhoto = false);
    }
  }

  Future<_PhotoChoice?> _previewPhoto(Uint8List photo) => showDialog<_PhotoChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Prévia da foto'),
          scrollable: true,
          content: Image.memory(
            photo,
            height: 220,
            fit: BoxFit.contain,
            semanticLabel: 'Foto capturada',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_PhotoChoice.retake),
              child: const Text('Tirar novamente'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(_PhotoChoice.use),
              child: const Text('Usar esta foto'),
            ),
          ],
        ),
      );

  Future<void> _linkNfc() async {
    if (_busy || _user == null) return;
    final uid = _uid.text.replaceAll(RegExp(r'[\s:-]'), '').toUpperCase();
    if (!RegExp(r'^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$').hasMatch(uid)) {
      setState(() {
        _nfcNotice = null;
        _nfcError = 'Informe um UID hexadecimal de 4, 7 ou 10 bytes.';
      });
      return;
    }
    if (_tags.any((tag) => tag.uid == uid)) {
      setState(() {
        _nfcNotice = null;
        _nfcError = 'Esta tag já está vinculada a este perfil.';
      });
      return;
    }
    setState(() {
      _working = true;
      _nfcError = null;
      _nfcNotice = null;
    });
    try {
      final tag = await widget.repository.addTag(_user!.id, uid);
      if (!mounted) return;
      _uid.clear();
      setState(() {
        _tags = [..._tags, tag];
        _nfcNotice = 'Tag ${tag.uid} vinculada a este perfil.';
      });
      unawaited(widget.onChanged());
    } catch (error) {
      if (!mounted) return;
      final api = ApiException.from(error);
      setState(() => _nfcError = api.kind == ApiErrorKind.conflict
          ? 'Este UID já foi cadastrado. Confira o vínculo antes de tentar novamente.'
          : api.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _saveFace(UsersRepository repository, String id) async {
    final photo = _photo;
    if (photo == null) return true;
    if (!_consent) return false;
    setState(() => _uploadingFace = true);
    try {
      final hasPhoto = await repository.saveFace(id, photo);
      if (!mounted) return false;
      setState(() {
        _hasFace = true;
        if (hasPhoto) _loadSavedPhoto = () async => photo;
        _photo = null;
        _consent = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
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
      return false;
    } finally {
      if (mounted) setState(() => _uploadingFace = false);
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
      _working = true;
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
      final savedFace = await _saveFace(repository, savedUser.id);
      if (!mounted) return;
      if (savedFace) {
        Navigator.of(context).pop(_notice);
      } else {
        unawaited(widget.onChanged());
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _retryFace() async {
    final user = _user;
    if (_busy || user == null) return;
    setState(() {
      _working = true;
      _faceError = null;
    });
    try {
      final savedFace = await _saveFace(widget.repository, user.id);
      if (!mounted || !savedFace) return;
      if (_notice != null && _model.changesFrom(user).isEmpty) {
        Navigator.of(context).pop(_notice);
      } else {
        unawaited(widget.onChanged());
      }
    } finally {
      if (mounted) setState(() => _working = false);
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
    setState(() => _working = true);
    try {
      await widget.repository.delete(_user!.id);
      if (!mounted) return;
      unawaited(widget.onChanged());
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
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
        appBar: AppBar(
          title: BrandedTitle(editing ? 'Editar usuário' : 'Novo usuário'),
        ),
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
            if (editing) ...[
              const Text('Foto atual'),
              const SizedBox(height: 8),
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
            ],
            AppSecondaryButton(
              label: loadSavedPhoto == null && photo == null
                  ? 'Tirar foto'
                  : 'Trocar foto',
              icon: Icons.camera_alt,
              onPressed: _busy ? null : _capture,
            ),
            if (photo != null) ...[
              const SizedBox(height: 12),
              const Text('Nova foto · pendente de envio'),
              const SizedBox(height: 8),
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
            if (_uploadingFace)
              const LinearProgressIndicator(semanticsLabel: 'Enviando foto'),
            if (_user != null &&
                photo != null &&
                _consent &&
                _faceError != null)
              TextButton(
                onPressed: _busy ? null : _retryFace,
                child: const Text('Tentar foto novamente'),
              ),
            if (_notice != null && _faceError != null)
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Voltar à lista'),
              ),
            const Divider(),
            Text('Tags NFC', style: Theme.of(context).textTheme.titleMedium),
            if (_user == null)
              const Text('Salve o usuário e reabra o perfil para vincular uma tag NFC.'),
            if (_user != null) ...[
              if (_tags.isEmpty) const Text('Nenhuma tag vinculada.'),
              for (final tag in _tags) Text(tag.uid),
              TextFormField(
                controller: _uid,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'UID da tag NFC',
                  hintText: 'Ex.: 04:A3:2F:1B',
                ),
                autocorrect: false,
                onChanged: (_) {
                  if (_nfcError == null && _nfcNotice == null) return;
                  setState(() {
                    _nfcError = null;
                    _nfcNotice = null;
                  });
                },
              ),
              TextButton(
                onPressed: _busy ? null : _linkNfc,
                child: const Text('Vincular tag NFC'),
              ),
            ],
            if (_nfcError case final String message)
              StatusMessage(kind: StatusKind.error, message: 'NFC: $message'),
            if (_nfcNotice case final String message)
              StatusMessage(kind: StatusKind.success, message: message),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Salvar usuário',
              isLoading: _working,
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
