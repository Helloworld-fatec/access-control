import '../../../core/widgets/status_message.dart';

/// Aviso mostrado no formulário (erro, informação ou sucesso).
class FormNotice {
  const FormNotice(this.kind, this.message);

  final StatusKind kind;
  final String message;

  static const String checkFields =
      'Confira os campos destacados e tente de novo.';
}
