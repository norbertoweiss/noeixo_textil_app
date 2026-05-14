import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaParametrosQualidade extends StatefulWidget {
  const TelaParametrosQualidade({super.key});

  @override
  State<TelaParametrosQualidade> createState() =>
      _TelaParametrosQualidadeState();
}

class _TelaParametrosQualidadeState extends State<TelaParametrosQualidade> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Qualidade (QA)'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.rule), text: 'Requisitos / Dicionário'),
              Tab(icon: Icon(Icons.gpp_maybe), text: 'Motivos de Liberação'),
            ],
          ),
        ),
        body: TabBarView(children: [_AbaRequisitos(), _AbaMotivosLiberacao()]),
      ),
    );
  }
}

// ============================================================================
// ABA 1: O DICIONÁRIO DE REQUISITOS
// ============================================================================
class _AbaRequisitos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parametros_qualidade')
            .orderBy('nome')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum requisito cadastrado.\nClique no + para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool ativo = data['ativo'] ?? true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ativo
                        ? Colors.deepPurple.shade100
                        : Colors.grey.shade300,
                    child: Icon(
                      Icons.verified,
                      color: ativo ? Colors.deepPurple : Colors.grey,
                    ),
                  ),
                  title: Text(
                    data['nome'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Etapa Alvo: ${data['etapa'] ?? 'Geral'}'),
                  trailing: Switch(
                    value: ativo,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) => FirebaseFirestore.instance
                        .collection('parametros_qualidade')
                        .doc(doc.id)
                        .update({'ativo': val}),
                  ),
                  onTap: () =>
                      _modalFormParametro(context, docId: doc.id, dados: data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'btnRequisito',
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: () => _modalFormParametro(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _modalFormParametro(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? dados,
  }) {
    String nome = dados?['nome'] ?? "";
    String etapa = dados?['etapa'] ?? "Produção";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? 'Novo Requisito' : 'Editar Requisito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nome do Parâmetro',
                hintText: 'Ex: Tensão do Elástico',
              ),
              controller: TextEditingController(text: nome),
              onChanged: (v) => nome = v,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: etapa,
              decoration: const InputDecoration(
                labelText: 'Etapa do Gatilho',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Materia-Prima',
                  child: Text('Recebimento MP / Insumo'),
                ),
                DropdownMenuItem(
                  value: 'Produção',
                  child: Text('Processo / Costura'),
                ),
                DropdownMenuItem(
                  value: 'Acabamento',
                  child: Text('Revisão Final'),
                ),
              ],
              onChanged: (v) => etapa = v!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nome.isNotEmpty) {
                final payload = {
                  'nome': nome,
                  'etapa': etapa,
                  'ativo': dados?['ativo'] ?? true,
                  'atualizadoEm': FieldValue.serverTimestamp(),
                };
                if (docId == null)
                  await FirebaseFirestore.instance
                      .collection('parametros_qualidade')
                      .add(payload);
                else
                  await FirebaseFirestore.instance
                      .collection('parametros_qualidade')
                      .doc(docId)
                      .update(payload);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 2: A LISTA DINÂMICA DE RISCO ASSUMIDO (MOTIVOS DE LIBERAÇÃO)
// ============================================================================
class _AbaMotivosLiberacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motivos_liberacao_qualidade')
            .orderBy('motivo')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum motivo cadastrado.\nClique no + para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool ativo = data['ativo'] ?? true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  title: Text(
                    data['motivo'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                    value: ativo,
                    activeColor: Colors.orange,
                    onChanged: (val) => FirebaseFirestore.instance
                        .collection('motivos_liberacao_qualidade')
                        .doc(doc.id)
                        .update({'ativo': val}),
                  ),
                  onTap: () => _modalFormMotivo(
                    context,
                    docId: doc.id,
                    motivoAtual: data['motivo'],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'btnMotivo',
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _modalFormMotivo(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _modalFormMotivo(
    BuildContext context, {
    String? docId,
    String? motivoAtual,
  }) {
    String motivo = motivoAtual ?? "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          docId == null ? 'Novo Motivo de Liberação' : 'Editar Motivo',
        ),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Justificativa',
            hintText: 'Ex: Urgência de Produção',
          ),
          controller: TextEditingController(text: motivo),
          onChanged: (v) => motivo = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (motivo.isNotEmpty) {
                final payload = {
                  'motivo': motivo,
                  'ativo': true,
                  'atualizadoEm': FieldValue.serverTimestamp(),
                };
                if (docId == null)
                  await FirebaseFirestore.instance
                      .collection('motivos_liberacao_qualidade')
                      .add(payload);
                else
                  await FirebaseFirestore.instance
                      .collection('motivos_liberacao_qualidade')
                      .doc(docId)
                      .update(payload);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
