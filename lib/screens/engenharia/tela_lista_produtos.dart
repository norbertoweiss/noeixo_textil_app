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

  // Variável para armazenar o que o utilizador está a digitar
  String _termoBusca = '';

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
      body: Column(
        children: [
          // --- BARRA DE PESQUISA ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar Produto (Nome ou Referência)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _termoBusca = val.toLowerCase();
                });
              },
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // --- LISTA DE PRODUTOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _produtosRef
                  .where('empresa_id', isEqualTo: widget.empresaId)
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar produtos. (Verifique o Console)',
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhum produto cadastrado para esta empresa.'),
                  );
                }

                // APLICA O FILTRO DA BUSCA ANTES DE RENDERIZAR
                final produtosFiltrados = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final ref = (data['referencia'] ?? '')
                      .toString()
                      .toLowerCase();

                  return _termoBusca.isEmpty ||
                      nome.contains(_termoBusca) ||
                      ref.contains(_termoBusca);
                }).toList();

                if (produtosFiltrados.isEmpty) {
                  return const Center(
                    child: Text('Nenhum produto encontrado na pesquisa.'),
                  );
                }

                return ListView.builder(
                  itemCount: produtosFiltrados.length,
                  itemBuilder: (context, index) {
                    final produto = produtosFiltrados[index];
                    final data = produto.data() as Map<String, dynamic>;

                    final isAcabado = data['tipo'] == 'Produto Acabado';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
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
          ),
        ],
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
