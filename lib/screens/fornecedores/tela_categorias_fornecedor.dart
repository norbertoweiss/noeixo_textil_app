import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_categoria_fornecedor.dart';

class TelaCategoriasFornecedor extends StatefulWidget {
  const TelaCategoriasFornecedor({super.key});

  @override
  State<TelaCategoriasFornecedor> createState() =>
      _TelaCategoriasFornecedorState();
}

class _TelaCategoriasFornecedorState extends State<TelaCategoriasFornecedor> {
  Future<void> _alterarStatus(String id, bool novoStatus) async {
    await FirebaseFirestore.instance
        .collection('categorias_fornecedor')
        .doc(id)
        .update({'ativo': novoStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Classes e Subclasses'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // A SOLUÇÃO: Removemos o .orderBy('nome') daqui para não travar no Firebase
        stream: FirebaseFirestore.instance
            .collection('categorias_fornecedor')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          // Adicionamos captura de erro para nunca mais a tela falhar em silêncio
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro do Banco de Dados:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma classe definida.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // A SOLUÇÃO: Ordenamos a lista alfabeticamente aqui, direto no dispositivo
          var documentos = snapshot.data!.docs;
          documentos.sort((a, b) {
            String nomeA =
                (a.data() as Map<String, dynamic>)['nome']
                    ?.toString()
                    .toLowerCase() ??
                '';
            String nomeB =
                (b.data() as Map<String, dynamic>)['nome']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return nomeA.compareTo(nomeB);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final doc = documentos[index];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              final ativo = data['ativo'] ?? true;

              final subgruposBrutos = data['subgrupos'] ?? [];
              List<String> nomesSubativos = [];

              for (var s in subgruposBrutos) {
                if (s is String) {
                  nomesSubativos.add(s);
                } else if (s is Map) {
                  if (s['ativo'] == true) {
                    nomesSubativos.add(s['nome']);
                  } else {
                    nomesSubativos.add('${s['nome']} (Inativo)');
                  }
                }
              }

              final descricao = data['descricao'] ?? '';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ativo
                        ? Colors.blueGrey[100]
                        : Colors.grey[200],
                    child: Icon(
                      Icons.account_tree,
                      color: ativo ? Colors.blueGrey : Colors.grey,
                    ),
                  ),
                  title: Text(
                    data['nome'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ativo ? Colors.black87 : Colors.grey,
                      decoration: ativo
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (descricao.toString().isNotEmpty)
                        Text(
                          'Finalidade: $descricao',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Subclasses: ${nomesSubativos.join(", ")}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blueGrey,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormCategoriaFornecedor(
                                categoriaParaEditar: doc,
                              ),
                            ),
                          );
                        },
                      ),
                      Switch(
                        value: ativo,
                        activeColor: Colors.blueGrey,
                        onChanged: (valor) => _alterarStatus(id, valor),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FormCategoriaFornecedor(),
            ),
          );
        },
        backgroundColor: Colors.blueGrey,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Classe', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
