import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_fornecedor.dart';
import 'tela_categorias_fornecedor.dart';

class TelaFornecedores extends StatefulWidget {
  const TelaFornecedores({super.key});

  @override
  State<TelaFornecedores> createState() => _TelaFornecedoresState();
}

class _TelaFornecedoresState extends State<TelaFornecedores> {
  String _termoBusca = '';

  Future<void> _alterarStatusFornecedor(String id, bool novoStatus) async {
    await FirebaseFirestore.instance.collection('fornecedores').doc(id).update({
      'ativo': novoStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 1,
        title: const Text('Fornecedores e Parceiros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: 'Configurar Classes e Insumos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaCategoriasFornecedor(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou CNPJ...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _termoBusca = valor.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fornecedores')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(
              child: Text(
                'Nenhum fornecedor cadastrado.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );

          var documentos = snapshot.data!.docs.where((doc) {
            final nome = (doc['nome'] ?? '').toString().toLowerCase();
            final documento = (doc['documento'] ?? '').toString().toLowerCase();
            return nome.contains(_termoBusca) ||
                documento.contains(_termoBusca);
          }).toList();

          if (documentos.isEmpty)
            return const Center(child: Text('Nenhum resultado para a busca.'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final data = documentos[index].data() as Map<String, dynamic>;
              final id = documentos[index].id;
              final ativo = data['ativo'] ?? true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ativo
                        ? Colors.blueGrey[100]
                        : Colors.grey[200],
                    child: Icon(
                      Icons.business,
                      color: ativo ? Colors.blueGrey : Colors.grey,
                    ),
                  ),
                  title: Text(
                    data['nome'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ativo
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                      color: ativo ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'CNPJ/CPF: ${data['documento']} | Contato: ${data['contato']}',
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${data['grupoNome']} > ${data['subcategoria']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: ativo,
                    activeColor: Colors.blueGrey,
                    onChanged: (valor) => _alterarStatusFornecedor(id, valor),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FormFornecedor()),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Novo Fornecedor',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
