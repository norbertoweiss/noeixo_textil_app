import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tela_ficha_tecnica_main.dart'; // <-- APONTAMENTO PARA O NOVO CÉREBRO

class TelaListaFichas extends StatefulWidget {
  final String empresaId;

  const TelaListaFichas({Key? key, required this.empresaId}) : super(key: key);

  @override
  _TelaListaFichasState createState() => _TelaListaFichasState();
}

class _TelaListaFichasState extends State<TelaListaFichas> {
  final CollectionReference _fichasRef = FirebaseFirestore.instance.collection(
    'fichas_tecnicas',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas Técnicas'),
        centerTitle: true,
        // --- CORREÇÃO DO BOTÃO DE VOLTAR NO WEB ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fichasRef
            .where('empresa_id', isEqualTo: widget.empresaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro crítico: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma ficha técnica encontrada para esta empresa.',
              ),
            );
          }

          // ORDENAÇÃO NA MEMÓRIA (Da mais recente para a mais antiga)
          final fichas = snapshot.data!.docs.toList();
          fichas.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA = dataA['criadoEm'] as Timestamp?;
            final timeB = dataB['criadoEm'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          return ListView.builder(
            itemCount: fichas.length,
            itemBuilder: (context, index) {
              final ficha = fichas[index];
              final data = ficha.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.description,
                    color: Colors.brown,
                    size: 40,
                  ),
                  title: Text(data['produtoNome'] ?? 'Sem nome'),
                  subtitle: Text(
                    'Referência: ${data['referencia']} | Grade: ${data['gradeNome']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // --- GATILHO DE NAVEGAÇÃO PARA A EDIÇÃO (NOVO CÉREBRO) ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaFichaTecnicaMain(
                          empresaId: widget.empresaId,
                          fichaId: ficha.id,
                          dadosAtuais: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown,
        onPressed: () {
          // --- GATILHO DE NAVEGAÇÃO PARA NOVA FICHA (NOVO CÉREBRO) ---
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TelaFichaTecnicaMain(empresaId: widget.empresaId),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
