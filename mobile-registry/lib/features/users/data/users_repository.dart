import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import 'user_models.dart';

/// Resultado de substituir uma tag: a nova sempre foi vinculada; a remoção da
/// antiga pode ter falhado ([removeError]).
class TagReplaceResult {
  const TagReplaceResult(this.added, {this.removeError});

  final NfcTag added;
  final ApiException? removeError;

  bool get oldTagRemoved => removeError == null;
}

/// Acesso às rotas de usuários do backend, só pelo cliente HTTP único.
/// Toda falha sai como [ApiException] com mensagem pronta para a tela.
class UsersRepository {
  UsersRepository(this._dio);

  final Dio _dio;

  static const String unexpectedResponseMessage =
      'O servidor respondeu algo inesperado. Tente novamente.';

  /// Mensagem fixa para UID repetido: nunca repassamos texto do servidor que
  /// possa identificar o dono da tag.
  static const String tagConflictMessage = 'Esta tag já está cadastrada.';

  /// `GET /users` (paginado). Parâmetros vazios não são enviados.
  Future<UsersPage> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    UserRole? role,
    bool? active,
  }) {
    final term = search.trim();
    return _call(
      () => _dio.get<dynamic>(
        '/users',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (term.isNotEmpty) 'search': term,
          if (role != null) 'role': role.value,
          if (active != null) 'active': active.toString(),
        },
      ),
      UsersPage.fromJson,
    );
  }

  /// `GET /users/{id}`: dados completos, com tags NFC e situação do rosto.
  Future<UserDetail> get(String id) =>
      _call(() => _dio.get<dynamic>('/users/$id'), UserDetail.fromJson);

  /// `POST /users`.
  Future<UserSummary> create(NewUser user) => _call(
        () => _dio.post<dynamic>('/users', data: user.toJson()),
        UserSummary.fromJson,
      );

  /// `PUT /users/{id}` só com os campos alterados (o backend aceita parcial).
  Future<UserSummary> update(String id, Map<String, Object?> changes) => _call(
        () => _dio.put<dynamic>('/users/$id', data: changes),
        UserSummary.fromJson,
      );

  /// `PATCH /users/{id}/status`: ativa ou desativa (o histórico é preservado).
  Future<UserSummary> setActive(String id, {required bool active}) => _call(
        () => _dio.patch<dynamic>('/users/$id/status', data: {'active': active}),
        UserSummary.fromJson,
      );

  /// `POST /users/{id}/tags`: vincula uma tag (UID já padronizado).
  /// Se o UID for de outro usuário o backend responde 409; a mensagem
  /// exibida é genérica e não revela de quem é a tag.
  Future<NfcTag> addTag(String userId, String uid) async {
    try {
      return await _call(
        () => _dio.post<dynamic>('/users/$userId/tags', data: {'uid': uid}),
        NfcTag.fromJson,
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.conflict) {
        throw ApiException(
          kind: ApiErrorKind.conflict,
          message: tagConflictMessage,
          statusCode: e.statusCode,
          code: e.code,
        );
      }
      rethrow;
    }
  }

  /// `DELETE /users/{id}/tags/{tagId}`. Tag que já não existe (404) conta
  /// como removida: o resultado desejado foi alcançado (ex.: a primeira
  /// tentativa funcionou e só a resposta se perdeu antes de uma nova tentativa).
  Future<void> removeTag(String userId, String tagId) async {
    try {
      await _dio.delete<dynamic>('/users/$userId/tags/$tagId');
    } catch (e) {
      final api = ApiException.from(e);
      if (api.kind == ApiErrorKind.notFound) return;
      throw api;
    }
  }

  /// Substitui uma tag: VINCULA A NOVA primeiro e só então remove a antiga.
  /// Assim, se a nova der conflito ou falhar, o usuário continua com a tag
  /// que tinha (nunca fica sem acesso). Se a nova entrar mas a remoção falhar,
  /// o resultado informa isso para a tela avisar.
  Future<TagReplaceResult> replaceTag({
    required String userId,
    required String oldTagId,
    required String newUid,
  }) async {
    final added = await addTag(userId, newUid); // falha aqui: nada mudou
    try {
      await removeTag(userId, oldTagId);
      return TagReplaceResult(added);
    } on ApiException catch (e) {
      return TagReplaceResult(added, removeError: e);
    }
  }

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } catch (e) {
      throw ApiException.from(e);
    }

    try {
      final body = response.data;
      if (body is! Map) throw const FormatException('Corpo não é um objeto');
      return parse(Map<String, dynamic>.from(body));
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: unexpectedResponseMessage,
      );
    }
  }
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(dioProvider)),
);
