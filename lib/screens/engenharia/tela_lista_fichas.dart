import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_ficha_tecnica.dart';

class TelaListaFichas extends StatefulWidget {
  const TelaListaFichas({Key? key}) : super(key: key);

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
        stream: _fichasRef.orderBy('criadoEm', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma ficha técnica encontrada.'),
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
            MaterialPageRoute(builder: (context) => const FormFichaTecnica()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
