import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:noeixo_textil_app/screens/comercial/gestao/tela_checklist_aprovacao.dart';

// AJUSTE O CAMINHO PARA A TELA DE CHECKLIST QUE CRIAMOS LÁ NO COMERCIAL

class TelaFilaAprovacaoFinanceira extends StatelessWidget {
  final String empresaId; // <-- ADICIONADO PARA RECEBER A EMPRESA

  const TelaFilaAprovacaoFinanceira({
    super.key,
    required this.empresaId,
  }); // <-- ADICIONADO NO CONSTRUTOR

  @override
  Widget build(BuildContext context) {
    final formatadorMoeda = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    final formatadorData = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Análise de Crédito (Pedidos)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ESCUTA APENAS PEDIDOS QUE O COMERCIAL JÁ LIBEROU
        // REMOVIDO o .orderBy() para evitar o erro de Índice Composto do Firebase
        stream: FirebaseFirestore.instance
            .collection('pedidos_venda')
            .where('status_financeiro', isEqualTo: 'Em Análise')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Agora mostramos o erro exato do Firebase para facilitar depuração
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro do Firebase:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );

          var documentos = snapshot.data?.docs ?? [];

          // ========================================================
          // ORDENAÇÃO NA MEMÓRIA (Substitui o orderBy do Firebase)
          // ========================================================
          documentos.sort((a, b) {
            var dataA =
                (a.data() as Map<String, dynamic>)['dataPedido'] as Timestamp?;
            var dataB =
                (b.data() as Map<String, dynamic>)['dataPedido'] as Timestamp?;
            if (dataA == null && dataB == null) return 0;
            if (dataA == null) return 1;
            if (dataB == null) return -1;
            return dataB.compareTo(
              dataA,
            ); // Ordem decrescente (mais novos primeiro)
          });

          if (documentos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.teal.shade200,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fila limpa!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Text(
                    'Nenhum pedido aguardando liberação de crédito.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final doc = documentos[index];
              final data = doc.data() as Map<String, dynamic>;

              final clienteNome = data['clienteNome'] ?? 'Desconhecido';
              final valorTotal = (data['valorFinalCobrado'] ?? 0).toDouble();
              final condicaoPgto = data['condicaoPagamento'] ?? '-';
              final formaPgto = data['formaPagamento'] ?? '-';
              final dataPedido = (data['dataPedido'] as Timestamp?)?.toDate();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              clienteNome,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ),
                          Text(
                            formatadorMoeda.format(valorTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.payment,
                            size: 16,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Condição Solicitada: $formaPgto ($condicaoPgto)',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dataPedido != null
                                ? 'Data do Pedido: ${formatadorData.format(dataPedido)}'
                                : 'Data não informada',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text(
                            'AVALIAR CRÉDITO (ABRIR CHECKLIST)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaChecklistAprovacao(
                                  empresaId:
                                      empresaId, // <-- REPASSANDO PARA O CHECKLIST
                                  pedidoId: doc.id,
                                  clienteNome: clienteNome,
                                  valorPedido: valorTotal,
                                  tipoAprovacao: 'Financeiro',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
