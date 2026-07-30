import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_condicao_pagamento.dart';

class TelaListaCondicoesPagamento extends StatelessWidget {
  const TelaListaCondicoesPagamento({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condições de Pagamento'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('condicoes_pagamento')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Erro ao carregar dados.'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final documentos = snapshot.data!.docs;

          if (documentos.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma condição de pagamento cadastrada.',
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
              final qtdParcelas = data['qtd_parcelas'] ?? 1;
              final primeiroVencimento = data['dias_primeiro_vencimento'] ?? 0;
              final intervalo = data['intervalo_dias'] ?? 0;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(
                      Icons.rule_folder,
                      color: Colors.orange.shade800,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$qtdParcelas Parcela(s) | 1º Venc: $primeiroVencimento dias | Intervalo: $intervalo dias',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: ativo,
                        onChanged: (bool valor) {
                          FirebaseFirestore.instance
                              .collection('condicoes_pagamento')
                              .doc(documentos[index].id)
                              .update({'ativo': valor});
                        },
                        activeColor: Colors.orange.shade700,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('condicoes_pagamento')
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
        backgroundColor: Colors.orange.shade700,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FormCondicaoPagamento(),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
