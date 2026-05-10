import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEstoqueMateriaPrima extends StatefulWidget {
  const TelaEstoqueMateriaPrima({super.key});

  @override
  State<TelaEstoqueMateriaPrima> createState() =>
      _TelaEstoqueMateriaPrimaState();
}

class _TelaEstoqueMateriaPrimaState extends State<TelaEstoqueMateriaPrima> {
  String _termoBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Estoque de Matéria-Prima'),
        backgroundColor: Colors.brown, // Cor do botão no menu principal
        foregroundColor: Colors.white,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar insumo ou classe...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _termoBusca = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _termoBusca = valor.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lemos os insumos para ver o saldo
        stream: FirebaseFirestore.instance
            .collection('insumos')
            .where('clienteId', isEqualTo: 'teste_textil')
            .where(
              'ativo',
              isEqualTo: true,
            ) // Só mostra insumos ativos no estoque
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum insumo ativo no cadastro.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          var documentos = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nome = (data['nome'] ?? '').toString().toLowerCase();
            final classe = (data['classe'] ?? '').toString().toLowerCase();
            return _termoBusca.isEmpty ||
                nome.contains(_termoBusca) ||
                classe.contains(_termoBusca);
          }).toList();

          if (documentos.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum resultado encontrado.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final data = documentos[index].data() as Map<String, dynamic>;

              // Se o campo estoqueAtual ainda não existir no Firebase, assumimos 0
              final double estoqueAtual = (data['estoqueAtual'] ?? 0.0)
                  .toDouble();
              final double estoqueMinimo = (data['estoqueMinimo'] ?? 0.0)
                  .toDouble();
              final String unidade = data['unidade'] ?? 'un';
              final imagemBase64 = data['imagemBase64'];

              // Lógica de alerta visual
              bool estoqueBaixo = estoqueAtual <= estoqueMinimo;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: estoqueBaixo
                        ? Colors.red.shade300
                        : Colors.transparent,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: imagemBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(imagemBase64),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.inventory_2, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['nome'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['classe'] ?? ''} > ${data['subclasse'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$estoqueAtual $unidade',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: estoqueBaixo
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Mín: $estoqueMinimo',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ajuste de inventário será liberado na fase de PCP.',
              ),
            ),
          );
        },
        child: const Icon(Icons.sync_alt, color: Colors.white),
      ),
    );
  }
}
