import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_entrada_manual.dart';
import 'form_entrada_itens.dart';

class TelaEntradaConferencia extends StatefulWidget {
  const TelaEntradaConferencia({super.key});

  @override
  State<TelaEntradaConferencia> createState() => _TelaEntradaConferenciaState();
}

class _TelaEntradaConferenciaState extends State<TelaEntradaConferencia> {
  void _abrirOpcoesEntrada(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja registrar a entrada?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.qr_code_scanner, color: Colors.white),
                  ),
                  title: const Text(
                    'Importar XML Automático',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Lê os itens e gera o financeiro sozinho.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Módulo XML em desenvolvimento.'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.keyboard, color: Colors.teal),
                  ),
                  title: const Text(
                    'Digitação Manual',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Notas Frias, Recibos ou Ajustes.'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FormEntradaManual(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Entrada e Conferência'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade700,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel de Recebimento',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Acompanhe e efetive suas notas',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // SOLUÇÃO 1: Removido o orderBy que estava a causar a falha silenciosa
              stream: FirebaseFirestore.instance
                  .collection('entradas_estoque')
                  .where('clienteId', isEqualTo: 'teste_textil')
                  .snapshots(),
              builder: (context, snapshot) {
                // SOLUÇÃO 2: Trava de Segurança para Erros
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar dados:\n${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhuma entrada registrada.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // SOLUÇÃO 3: Ordenação Local (Do mais recente para o mais antigo)
                var documentos = snapshot.data!.docs;
                documentos.sort((a, b) {
                  Timestamp? tA =
                      (a.data() as Map<String, dynamic>)['dataRegistro']
                          as Timestamp?;
                  Timestamp? tB =
                      (b.data() as Map<String, dynamic>)['dataRegistro']
                          as Timestamp?;
                  if (tA == null && tB == null) return 0;
                  if (tA == null) return 1;
                  if (tB == null) return -1;
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final doc = documentos[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String status = data['status'] ?? 'Pendente';
                    final bool isDigitacao = status == 'Em Digitação';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        onTap: () {
                          if (isDigitacao) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FormEntradaItens(
                                  tipoDocumento: data['tipoDocumento'],
                                  numeroDocumento: data['numeroDocumento'],
                                  fornecedorId: data['fornecedorId'],
                                  documentoId: doc
                                      .id, // O ID Mágico que carrega os itens
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nota efetivada. Somente visualização disponível.',
                                ),
                              ),
                            );
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isDigitacao
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            isDigitacao ? Icons.edit_note : Icons.check_circle,
                            color: isDigitacao
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                        title: Text(
                          'Doc: ${data['numeroDocumento'] != null && data['numeroDocumento'].toString().isNotEmpty ? data['numeroDocumento'] : 'S/N'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['tipoDocumento'] ?? ''),
                            Text(
                              'Valor: R\$ ${(data['valorTotal'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDigitacao
                                    ? Colors.orange
                                    : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(Icons.chevron_right, size: 16),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () => _abrirOpcoesEntrada(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Registrar Entrada',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
