import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:noeixo_textil_app/screens/financeiro/form_politica_comercial_financeira.dart';

// Ajuste o caminho de importação conforme a sua estrutura de pastas:

class TelaListaPoliticasComerciais extends StatelessWidget {
  final String empresaId; // Injetamos o ID da empresa para o Multi-Tenant

  const TelaListaPoliticasComerciais({super.key, required this.empresaId});

  // Função para inativar/ativar a regra instantaneamente
  Future<void> _alterarStatus(String docId, bool novoStatus) async {
    await FirebaseFirestore.instance
        .collection('politicas_comerciais')
        .doc(docId)
        .update({'ativo': novoStatus});
  }

  // Função para excluir definitivamente (com trava de segurança)
  Future<void> _excluirPolitica(
    BuildContext context,
    String docId,
    String nome,
  ) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Excluir Política?',
              style: TextStyle(color: Colors.red),
            ),
            content: Text(
              'Tem a certeza que deseja excluir a regra "$nome"? Esta ação não pode ser desfeita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir Definitivamente'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      await FirebaseFirestore.instance
          .collection('politicas_comerciais')
          .doc(docId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Política excluída com sucesso!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Políticas Comerciais e Comissões'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('politicas_comerciais')
            .where('empresa_id', isEqualTo: empresaId)
            // A ordenação é feita na memória para evitar exigir índice composto no Firebase inicialmente
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar dados: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final documentos = snapshot.data?.docs ?? [];

          if (documentos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule_folder,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma regra configurada.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clique no botão + para criar sua primeira Política Comercial.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // Ordenar alfabeticamente na memória
          var listaFiltrada = documentos.toList();
          listaFiltrada.sort((a, b) {
            String nomeA =
                (a.data() as Map<String, dynamic>)['nome_politica']
                    ?.toString()
                    .toLowerCase() ??
                '';
            String nomeB =
                (b.data() as Map<String, dynamic>)['nome_politica']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return nomeA.compareTo(nomeB);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listaFiltrada.length,
            itemBuilder: (context, index) {
              final doc = listaFiltrada[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool ativo = data['ativo'] ?? true;
              final String nome = data['nome_politica'] ?? 'Sem Nome';
              final double descontoMaximo =
                  (data['desconto_maximo_permitido'] ?? 0.0).toDouble();
              final String acaoExtrapolacao =
                  data['acao_extrapolacao'] ?? 'Bloquear Venda';
              final String tipoComissao = data['tipo_comissao'] ?? 'Fixa';

              return Card(
                elevation: ativo ? 2 : 0,
                color: ativo ? Colors.white : Colors.grey.shade200,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: ativo
                        ? Colors.blueGrey.shade100
                        : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: ativo
                        ? Colors.teal.shade50
                        : Colors.grey.shade300,
                    child: Icon(
                      Icons.gavel,
                      color: ativo ? Colors.teal.shade700 : Colors.grey,
                    ),
                  ),
                  title: Text(
                    nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: ativo
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                      color: ativo ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '• Desconto Máx: $descontoMaximo% ($acaoExtrapolacao)',
                      ),
                      Text('• Comissão: $tipoComissao'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        tooltip: 'Editar Regra',
                        onPressed: () {
                          // Navega enviando o ID e os dados para o formulário abrir em modo Edição
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FormPoliticaComercialFinanceira(
                                    empresaId: empresaId,
                                    politicaId: doc.id,
                                    dadosAtuais: data,
                                  ),
                            ),
                          );
                        },
                      ),
                      Switch(
                        value: ativo,
                        activeColor: Colors.teal,
                        onChanged: (novoStatus) =>
                            _alterarStatus(doc.id, novoStatus),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Excluir Definitivamente',
                        onPressed: () =>
                            _excluirPolitica(context, doc.id, nome),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormPoliticaComercialFinanceira(
                empresaId:
                    empresaId, // Enviamos a empresa para ele salvar no banco
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Política'),
      ),
    );
  }
}
