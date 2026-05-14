import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_processo.dart';

class TelaListaProcessos extends StatefulWidget {
  const TelaListaProcessos({super.key});

  @override
  State<TelaListaProcessos> createState() => _TelaListaProcessosState();
}

class _TelaListaProcessosState extends State<TelaListaProcessos> {
  String _filtroAtual = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Processos de Engenharia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _construirFiltro(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('processos_engenharia')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum processo cadastrado.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Filtrar Interno/Externo
                var documentos = snapshot.data!.docs.where((doc) {
                  final tipo = doc['tipo'] ?? 'Interno';
                  if (_filtroAtual == 'Fábrica') return tipo == 'Interno';
                  if (_filtroAtual == 'Facção') return tipo == 'Externo';
                  return true;
                }).toList();

                // Agrupar por Setor
                Map<String, List<QueryDocumentSnapshot>> processosPorSetor = {};
                for (var doc in documentos) {
                  String setor = doc['setor'] ?? 'Outros';
                  if (!processosPorSetor.containsKey(setor)) {
                    processosPorSetor[setor] = [];
                  }
                  processosPorSetor[setor]!.add(doc);
                }

                // Obter as chaves (Setores) ordenadas alfabeticamente
                List<String> setores = processosPorSetor.keys.toList()..sort();

                return ListView.builder(
                  itemCount: setores.length,
                  itemBuilder: (context, index) {
                    String setor = setores[index];
                    List<QueryDocumentSnapshot> operacoes =
                        processosPorSetor[setor]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho do Setor
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: Colors.teal.shade50,
                          child: Text(
                            setor.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Lista de Operações daquele Setor
                        ...operacoes.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isInterno = data['tipo'] == 'Interno';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isInterno
                                    ? Colors.teal.shade100
                                    : Colors.indigo.shade100,
                                child: Icon(
                                  isInterno
                                      ? Icons.precision_manufacturing
                                      : Icons.local_shipping,
                                  color: isInterno
                                      ? Colors.teal
                                      : Colors.indigo,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['nome'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isInterno
                                          ? Colors.teal
                                          : Colors.indigo,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isInterno ? 'INTERNA' : 'EXTERNA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Custo Padrão: R\$ ${data['custoPadrao']?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FormProcesso(
                                        processoId: doc.id,
                                        dadosAtuais: data,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 10),
                      ],
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
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'NOVO PROCESSO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FormProcesso()),
        ),
      ),
    );
  }

  Widget _construirFiltro() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Todos', label: Text('Todos')),
          ButtonSegment(value: 'Fábrica', label: Text('Fábrica')),
          ButtonSegment(value: 'Facção', label: Text('Facção')),
        ],
        selected: {_filtroAtual},
        onSelectionChanged: (Set<String> novaSelecao) {
          setState(() => _filtroAtual = novaSelecao.first);
        },
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Colors.teal,
        ),
      ),
    );
  }
}
