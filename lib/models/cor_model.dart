import 'dart:typed_data';

class CorModel {
  String id;
  String clienteId;
  String codigo; // NOVO CAMPO ADICIONADO
  String nome;
  bool ativo;
  Uint8List? imagemBytes;

  CorModel({
    required this.id,
    required this.clienteId,
    required this.codigo, // NOVO CAMPO
    required this.nome,
    required this.ativo,
    this.imagemBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'codigo': codigo, // NOVO CAMPO
      'nome': nome,
      'ativo': ativo,
    };
  }
}
