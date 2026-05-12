import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_processo.dart';

class TelaListaProcessos extends StatefulWidget {
  const TelaListaProcessos({super.key});

  @override
  State<TelaListaProcessos> createState() => _TelaListaProcessosState();
}

class _TelaListaProcessosState extends State<TelaListaProcessos> {
  // Estado do Filtro
  String _filtro = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processos de Engenharia'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // PAINEL DE FILTROS SUPERIOR
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
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
                      ButtonSegment(value: 'Interna', label: Text('Fábrica')),
                      ButtonSegment(value: 'Externa', label: Text('Facção')),
                    ],
                    selected: {_filtro},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _filtro = newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) {
                          if (states.contains(MaterialState.selected))
                            return Colors.teal.shade100;
                          return Colors.white;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 2),

          // LISTA DE PROCESSOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('engenharia_processos')
                  .where('clienteId', isEqualTo: 'teste_textil')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // FILTRAGEM NA MEMÓRIA
                var listaFiltrada = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final execucao = data['execucao'] ?? 'Interna';
                  if (_filtro != 'Todos' && execucao != _filtro) return false;
                  return true;
                }).toList();

                if (listaFiltrada.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum processo encontrado para este filtro.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    final doc = listaFiltrada[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final DateTime? dataAtt =
                        (data['dataUltimaAtualizacao'] as Timestamp?)?.toDate();

                    // Identificação Visual do Local de Execução
                    final String execucao = data['execucao'] ?? 'Interna';
                    final bool isInterno = execucao == 'Interna';

                    // Cálculo de expiração (180 dias = 6 meses)
                    bool defasado = false;
                    if (dataAtt != null) {
                      defasado =
                          DateTime.now().difference(dataAtt).inDays > 180;
                    }

                    return Card(
                      elevation: 2,
                      color: defasado ? Colors.amber.shade50 : Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isInterno
                              ? Colors.teal.shade100
                              : Colors.indigo.shade100,
                          // Se estiver defasado, mostra o Alerta. Se não, mostra o ícone de Fábrica ou Camião.
                          child: Icon(
                            defasado
                                ? Icons.warning_amber_rounded
                                : (isInterno
                                      ? Icons.precision_manufacturing
                                      : Icons.local_shipping),
                            color: defasado
                                ? Colors.orange
                                : (isInterno ? Colors.teal : Colors.indigo),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              data['nome'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ETIQUETA VISUAL (CHIP) DE INTERNO/EXTERNO
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isInterno ? Colors.teal : Colors.indigo,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                execucao.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Custo Padrão: R\$ ${data['custoPadrao'].toStringAsFixed(2)} (${data['baseCusto']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (dataAtt != null)
                              Text(
                                'Última revisão: ${dataAtt.day}/${dataAtt.month}/${dataAtt.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: defasado ? Colors.red : Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FormProcesso(documento: doc),
                            ),
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FormProcesso()),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'NOVO PROCESSO',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
