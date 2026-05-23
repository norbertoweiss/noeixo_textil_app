import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_ficha_tecnica.dart';

class TelaListaFichas extends StatefulWidget {
  final String empresaId; // <-- 1. CHAVE MESTRA RECEBIDA AQUI

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
      appBar: AppBar(title: const Text('Fichas Técnicas'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        // 2. TRAVA DE ISOLAMENTO: Filtra as fichas apenas para esta empresa
        stream: _fichasRef
            .where('empresa_id', isEqualTo: widget.empresaId)
            .orderBy('criadoEm', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // FORÇA O FLUTTER A CUSPIR O LINK DO ÍNDICE NO CONSOLE (F12) DO CHROME
            print('🔥🔥🔥 LINK DO ÍNDICE FIREBASE AQUI: ${snapshot.error}');
            return const Center(
              child: Text(
                'Erro ao carregar fichas. (Verifique o Console do F12)',
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

          final fichas = snapshot.data!.docs;

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormFichaTecnica(
                          empresaId: widget
                              .empresaId, // <-- 3. CHAVE REPASSADA PARA O BOTÃO EDITAR
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormFichaTecnica(
                empresaId: widget
                    .empresaId, // <-- 4. CHAVE REPASSADA PARA O BOTÃO NOVO (+)
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
