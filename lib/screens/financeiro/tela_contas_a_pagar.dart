import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaContasAPagar extends StatefulWidget {
  const TelaContasAPagar({super.key});

  @override
  State<TelaContasAPagar> createState() => _TelaContasAPagarState();
}

class _TelaContasAPagarState extends State<TelaContasAPagar> {
  // Filtros padrão: Do dia 1 do mês atual até o último dia do mês seguinte
  DateTime _dataInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dataFim = DateTime(
    DateTime.now().year,
    DateTime.now().month + 2,
    0,
  );

  // Status: 'Todos', 'Pendente' (A Pagar), 'Pago'
  String _statusFiltro = 'Todos';

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = escolhida;
        } else {
          _dataFim = escolhida;
        }
      });
    }
  }

  void _alternarStatus(String docId, String statusAtual) {
    String novoStatus = statusAtual == 'Pendente' ? 'Pago' : 'Pendente';
    FirebaseFirestore.instance.collection('contas_a_pagar').doc(docId).update({
      'status': novoStatus,
      'dataPagamento': novoStatus == 'Pago'
          ? FieldValue.serverTimestamp()
          : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a Pagar'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // PAINEL DE FILTROS
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selecionarData(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data Inicial',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatarData(_dataInicio)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selecionarData(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data Final',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatarData(_dataFim)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Mostrar: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Todos', label: Text('Todos')),
                          ButtonSegment(
                            value: 'Pendente',
                            label: Text('A Pagar'),
                          ),
                          ButtonSegment(value: 'Pago', label: Text('Pagos')),
                        ],
                        selected: {_statusFiltro},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() => _statusFiltro = newSelection.first);
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>((
                                states,
                              ) {
                                if (states.contains(MaterialState.selected))
                                  return Colors.red.shade100;
                                return Colors.white;
                              }),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 2),

          // LISTA DE CONTAS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Busca todas as contas do cliente
              stream: FirebaseFirestore.instance
                  .collection('contas_a_pagar')
                  .where('clienteId', isEqualTo: 'teste_textil')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text('Erro ao carregar os dados.'),
                  );
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                var documentos = snapshot.data!.docs;

                // FILTRAGEM NA MEMÓRIA (Evita erros de índice do Firebase)
                var listaFiltrada = documentos.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var status = data['status'] ?? 'Pendente';
                  Timestamp? vencimentoTs = data['dataVencimento'];

                  if (vencimentoTs == null) return false;
                  DateTime dataVenc = vencimentoTs.toDate();
                  DateTime vencNormalized = DateTime(
                    dataVenc.year,
                    dataVenc.month,
                    dataVenc.day,
                  );
                  DateTime startNormalized = DateTime(
                    _dataInicio.year,
                    _dataInicio.month,
                    _dataInicio.day,
                  );
                  DateTime endNormalized = DateTime(
                    _dataFim.year,
                    _dataFim.month,
                    _dataFim.day,
                  );

                  // 1. Filtro de Status
                  if (_statusFiltro != 'Todos' && status != _statusFiltro)
                    return false;

                  // 2. Filtro de Data
                  if (vencNormalized.isBefore(startNormalized) ||
                      vencNormalized.isAfter(endNormalized))
                    return false;

                  return true;
                }).toList();

                // ORDENAR POR DATA DE VENCIMENTO
                listaFiltrada.sort((a, b) {
                  var tA =
                      (a.data() as Map<String, dynamic>)['dataVencimento']
                          as Timestamp;
                  var tB =
                      (b.data() as Map<String, dynamic>)['dataVencimento']
                          as Timestamp;
                  return tA.compareTo(tB);
                });

                if (listaFiltrada.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Nenhuma conta no período selecionado.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // CÁLCULO DOS TOTAIS DA TELA
                double totalAberto = 0;
                double totalPago = 0;
                for (var doc in listaFiltrada) {
                  var d = doc.data() as Map<String, dynamic>;
                  if (d['status'] == 'Pago')
                    totalPago += (d['valor'] ?? 0);
                  else
                    totalAberto += (d['valor'] ?? 0);
                }

                return Column(
                  children: [
                    // RESUMO FINANCEIRO
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      color: Colors.grey.shade200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'A Pagar: R\$ ${totalAberto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            'Pago: R\$ ${totalPago.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: listaFiltrada.length,
                        itemBuilder: (context, index) {
                          final doc = listaFiltrada[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String status = data['status'] ?? 'Pendente';
                          final bool isPendente = status == 'Pendente';
                          final DateTime vencimento =
                              (data['dataVencimento'] as Timestamp).toDate();

                          // Verifica se está atrasado (se for pendente e a data já passou)
                          final bool atrasado =
                              isPendente &&
                              vencimento.isBefore(
                                DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                ),
                              );

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: atrasado
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPendente
                                    ? (atrasado
                                          ? Colors.red.shade100
                                          : Colors.orange.shade100)
                                    : Colors.green.shade100,
                                child: Icon(
                                  isPendente
                                      ? (atrasado
                                            ? Icons.warning
                                            : Icons.schedule)
                                      : Icons.done_all,
                                  color: isPendente
                                      ? (atrasado
                                            ? Colors.red
                                            : Colors.orange.shade800)
                                      : Colors.green.shade800,
                                ),
                              ),
                              title: Text(
                                'Doc: ${data['numeroDocumento']} (Parc: ${data['parcela']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Venc: ${_formatarData(vencimento)}',
                                    style: TextStyle(
                                      color: atrasado
                                          ? Colors.red
                                          : Colors.black87,
                                      fontWeight: atrasado
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    'R\$ ${(data['valor'] ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPendente
                                      ? Colors.green
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                icon: Icon(
                                  isPendente ? Icons.attach_money : Icons.undo,
                                  size: 16,
                                ),
                                label: Text(isPendente ? 'BAIXAR' : 'DESFAZER'),
                                onPressed: () =>
                                    _alternarStatus(doc.id, status),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
