import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_forma_pagamento.dart';

class TelaListaFormasPagamento extends StatelessWidget {
  const TelaListaFormasPagamento({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formas de Pagamento'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('formas_pagamento')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar dados.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final documentos = snapshot.data!.docs;

          if (documentos.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma forma de pagamento cadastrada.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final data = documentos[index].data() as Map<String, dynamic>;
              final nome = data['nome'] ?? 'Sem nome';
              final ativo = data['ativo'] ?? true;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: ativo,
                        onChanged: (bool valor) {
                          FirebaseFirestore.instance
                              .collection('formas_pagamento')
                              .doc(documentos[index].id)
                              .update({'ativo': valor});
                        },
                        activeColor: Colors.teal,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('formas_pagamento')
                              .doc(documentos[index].id)
                              .delete();
                        },
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
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormFormaPagamento()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
