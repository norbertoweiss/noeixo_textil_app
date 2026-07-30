import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:noeixo_textil_app/screens/configuracoes/tela_configuracao_checklist.dart';

// Importe a tela de checklist que já criamos para a avaliação
import '../comercial/gestao/tela_checklist_aprovacao.dart';

// IMPORT NOVO: A tela de configuração (Construtor de Checklists)

class TelaMaestroPCP extends StatefulWidget {
  final String empresaId;

  const TelaMaestroPCP({super.key, required this.empresaId});

  @override
  State<TelaMaestroPCP> createState() => _TelaMaestroPCPState();
}

class _TelaMaestroPCPState extends State<TelaMaestroPCP> {
  final _formatadorData = DateFormat('dd/MM/yyyy');

  // Função para calcular a urgência e retornar a cor do semáforo
  Color _calcularCorSemaforo(DateTime? dataEntrega) {
    if (dataEntrega == null) return Colors.grey;

    final diasRestantes = dataEntrega.difference(DateTime.now()).inDays;

    if (diasRestantes <= 7) {
      return Colors.red.shade600;
    } else if (diasRestantes <= 15) {
      return Colors.amber.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  Future<void> _abrirChecklistPCP(
    String pedidoId,
    Map<String, dynamic> dados,
  ) async {
    final bool? atualizou = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaChecklistAprovacao(
          empresaId: widget.empresaId,
          pedidoId: pedidoId,
          clienteNome: dados['clienteNome'] ?? 'Cliente Não Identificado',
          valorPedido: (dados['valorFinalCobrado'] ?? 0).toDouble(),
          tipoAprovacao: 'PCP',
        ),
      ),
    );

    if (atualizou == true) {
      setState(() {});
    }
  }

  // =========================================================================
  // NOVA FUNÇÃO: ABRIR O CONSTRUTOR DE CHECKLISTS (A ENGRENAGEM)
  // =========================================================================
  void _abrirConfiguracaoChecklist() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaConfiguracaoChecklist(
          empresaId: widget.empresaId,
          setorAcesso: 'PCP', // Garante que a aba PCP já abra focada
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        title: const Text(
          'Maestro PCP: Fila de Produção',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,

        // =========================================================================
        // INJEÇÃO DO BOTÃO DE ENGRENAGEM NO CANTO DIREITO
        // =========================================================================
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar Regras do PCP',
            onPressed: _abrirConfiguracaoChecklist,
          ),
          const SizedBox(width: 8), // Um pequeno respiro visual
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // O FILTRO CIRÚRGICO: Traz apenas o que o Comercial já aprovou
        stream: FirebaseFirestore.instance
            .collection('pedidos_venda')
            .where('status_pcp', isEqualTo: 'Em Análise')
            // Opcional no futuro: .where('empresa_id', isEqualTo: widget.empresaId) para garantir multi-tenant
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.precision_manufacturing,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fábrica Limpa!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Text(
                    'Nenhum pedido aguardando viabilidade no momento.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final pedidos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final doc = pedidos[index];
              final data = doc.data() as Map<String, dynamic>;

              // Tenta extrair a data de entrega prometida
              DateTime? dataEntrega;
              if (data['data_entrega_prometida'] != null) {
                dataEntrega = (data['data_entrega_prometida'] as Timestamp)
                    .toDate();
              } else if (data['dataPedido'] != null) {
                // Fallback temporário caso não exista campo de entrega: simula +15 dias do pedido
                dataEntrega = (data['dataPedido'] as Timestamp).toDate().add(
                  const Duration(days: 15),
                );
              }

              final corSemaforo = _calcularCorSemaforo(dataEntrega);

              // Cálculo de peças brutas para visualização rápida
              int totalPecas = 0;
              if (data['itens'] != null) {
                for (var item in data['itens']) {
                  totalPecas += (item['quantidadeTotal'] ?? 0) as int;
                }
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: corSemaforo,
                    width: 2,
                  ), // A cor indica a urgência
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['clienteNome'] ?? 'Sem Cliente',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: corSemaforo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer, size: 14, color: corSemaforo),
                                const SizedBox(width: 4),
                                Text(
                                  dataEntrega != null
                                      ? _formatadorData.format(dataEntrega)
                                      : 'Sem Data',
                                  style: TextStyle(
                                    color: corSemaforo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 20,
                            color: Colors.blueGrey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalPecas peças na carga',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.rule),
                          label: const Text(
                            'AVALIAR VIABILIDADE (CHECKLIST)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          onPressed: () => _abrirChecklistPCP(doc.id, data),
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
