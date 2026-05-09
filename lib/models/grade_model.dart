class GradeModel {
  String id;
  String clienteId;
  String nome;
  List<String> tamanhos;
  bool ativo;

  // Construtor com variáveis obrigatórias (required)
  GradeModel({
    required this.id,
    required this.clienteId,
    required this.nome,
    required this.tamanhos,
    required this.ativo,
  });

  // Transforma o Objeto em um Mapa (JSON) para salvar no Firebase Firestore
  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'nome': nome,
      'tamanhos': tamanhos,
      'ativo': ativo,
    };
  }

  // Transforma o Mapa (JSON) que vem do Firebase em um Objeto Dart
  factory GradeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return GradeModel(
      id: documentId, // O ID do documento no Firebase se torna o ID do objeto
      clienteId: map['clienteId'] ?? '',
      nome: map['nome'] ?? '',
      tamanhos: List<String>.from(map['tamanhos'] ?? []),
      ativo: map['ativo'] ?? true,
    );
  }
}
