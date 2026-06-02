import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_produto.dart';

class TelaListaProdutos extends StatefulWidget {
  final String empresaId;

  const TelaListaProdutos({Key? key, required this.empresaId})
    : super(key: key);

  @override
  _TelaListaProdutosState createState() => _TelaListaProdutosState();
}

class _TelaListaProdutosState extends State<TelaListaProdutos> {
  final CollectionReference _produtosRef = FirebaseFirestore.instance
      .collection('produtos');

  Future<void> _deletarProduto(String id) async {
    await _produtosRef.doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto excluído com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Produtos'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _produtosRef
            .where('empresa_id', isEqualTo: widget.empresaId)
            .orderBy('nome')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('🔥🔥🔥 LINK DO ÍNDICE FIREBASE AQUI: ${snapshot.error}');
            return const Center(
              child: Text(
                'Erro ao carregar produtos. (Verifique o Console do F12)',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhum produto cadastrado para esta empresa.'),
            );
          }

          final produtos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
              final data = produto.data() as Map<String, dynamic>;

              final isAcabado = data['tipo'] == 'Produto Acabado';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAcabado
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      isAcabado ? Icons.checkroom : Icons.category,
                      color: isAcabado
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  title: Text(data['nome'] ?? 'Sem nome'),
                  subtitle: Text(
                    'Ref: ${data['referencia']} | ${data['tipo']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormProduto(
                                empresaId: widget.empresaId,
                                produtoId: produto.id,
                                dadosAtuais: data,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () =>
                            _confirmarExclusao(context, produto.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormProduto(empresaId: widget.empresaId),
            ),
          );
        },
        tooltip: 'Novo Produto',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmarExclusao(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: const Text(
          'Tem certeza que deseja excluir este produto? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deletarProduto(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
