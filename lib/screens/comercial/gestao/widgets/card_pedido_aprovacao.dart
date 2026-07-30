import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CardPedidoAprovacao extends StatelessWidget {
  final String pedidoId;
  final Map<String, dynamic> data;
  final bool processandoAcao;
  final VoidCallback onDevolver;
  final VoidCallback onReprovar;
  final VoidCallback onAprovar;

  CardPedidoAprovacao({
    super.key,
    required this.pedidoId,
    required this.data,
    required this.processandoAcao,
    required this.onDevolver,
    required this.onReprovar,
    required this.onAprovar,
  });

  final _formatadorMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  final _formatadorDataHora = DateFormat('dd/MM/yyyy às HH:mm');

  // Máquina de Cores para os Semáforos
  Color _corSemaforo(String status) {
    if (status == 'Aprovado') return Colors.green;
    if (status == 'Devolvido' || status == 'Rejeitado' || status == 'Cancelado')
      return Colors.red;
    return Colors.amber.shade600; // Em Análise, Aguardando, etc.
  }

  IconData _iconeSemaforo(String status) {
    if (status == 'Aprovado') return Icons.check_circle;
    if (status == 'Devolvido' || status == 'Rejeitado' || status == 'Cancelado')
      return Icons.cancel;
    return Icons.timelapse;
  }

  @override
  Widget build(BuildContext context) {
    String statusComercial =
        data['status_comercial'] ?? data['status'] ?? 'Aguardando';
    String statusPCP = data['status_pcp'] ?? 'Aguardando Comercial';
    String statusFin = data['status_financeiro'] ?? 'Aguardando PCP';

    double valorFinal = (data['valorFinalCobrado'] ?? 0).toDouble();
    Timestamp? dataTs = data['dataPedido'] as Timestamp?;
    List itens = data['itens'] ?? [];

    // Define a cor da borda do card baseado no status comercial (que é o dono da tela)
    Color corBorda = _corSemaforo(statusComercial);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: corBorda.withOpacity(0.5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            data['clienteNome'] ?? 'Sem Nome',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Vend: ${data['representanteNome'] ?? '-'}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                dataTs != null
                    ? _formatadorDataHora.format(dataTs.toDate())
                    : '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatadorMoeda.format(valorFinal),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              // Mini-indicador de semáforos no card fechado
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconeSemaforo(statusComercial),
                    size: 14,
                    color: _corSemaforo(statusComercial),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _iconeSemaforo(statusPCP),
                    size: 14,
                    color: _corSemaforo(statusPCP),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _iconeSemaforo(statusFin),
                    size: 14,
                    color: _corSemaforo(statusFin),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              color: Colors.blueGrey.shade50.withOpacity(0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // =========================================================
                  // PAINEL DE TRÊS SEMÁFOROS (A Visão de Raio-X do Gestor)
                  // =========================================================
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status de Triagem Interna:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _linhaSemaforo(
                          '1. Comercial',
                          statusComercial,
                          Icons.storefront,
                        ),
                        const Divider(height: 16),
                        _linhaSemaforo(
                          '2. Fábrica (PCP)',
                          statusPCP,
                          Icons.precision_manufacturing,
                        ),
                        const Divider(height: 16),
                        _linhaSemaforo(
                          '3. Financeiro',
                          statusFin,
                          Icons.account_balance,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Resumo dos Itens:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        '${itens.length} modelos',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itens.length,
                    itemBuilder: (context, i) {
                      var item = itens[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['quantidadeTotal']}x ${item['nome']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              _formatadorMoeda.format(item['valorTotal'] ?? 0),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // BOTÕES DO COMERCIAL (Só aparecem se a bola ainda estiver com o Comercial)
                  if (statusComercial != 'Aprovado' &&
                      statusComercial != 'Cancelado' &&
                      statusComercial != 'Devolvido') ...[
                    const SizedBox(height: 24),
                    processandoAcao
                        ? const Center(child: LinearProgressIndicator())
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange),
                                ),
                                icon: const Icon(
                                  Icons.assignment_return,
                                  size: 16,
                                ),
                                label: const Text('Devolver ao Vend.'),
                                onPressed: onDevolver,
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                icon: const Icon(Icons.cancel, size: 16),
                                label: const Text('Reprovar'),
                                onPressed: onReprovar,
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.playlist_add_check_circle,
                                  size: 16,
                                ),
                                label: const Text('Meu Checklist Comercial'),
                                onPressed: onAprovar,
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaSemaforo(String setor, String status, IconData iconeSetor) {
    return Row(
      children: [
        Icon(iconeSetor, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            setor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _corSemaforo(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconeSemaforo(status),
                size: 12,
                color: _corSemaforo(status),
              ),
              const SizedBox(width: 4),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _corSemaforo(status),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
