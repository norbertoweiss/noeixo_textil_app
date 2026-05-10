import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'form_insumo.dart';

class TelaInsumos extends StatefulWidget {
  const TelaInsumos({super.key});

  @override
  State<TelaInsumos> createState() => _TelaInsumosState();
}

class _TelaInsumosState extends State<TelaInsumos> {
  String _termoBusca = '';
  String _filtroStatus = 'Ativos';
  String _filtroCategoria = 'Todos';

  void _limparFiltros() {
    setState(() {
      _termoBusca = '';
      _filtroStatus = 'Ativos';
      _filtroCategoria = 'Todos';
    });
  }

  Future<void> _alterarStatus(String id, bool novoStatus) async {
    await FirebaseFirestore.instance.collection('insumos').doc(id).update({
      'ativo': novoStatus,
    });
  }

  Widget _chipStatus(String rotulo, Color corFundo) {
    bool selecionado = _filtroStatus == rotulo;
    return ChoiceChip(
      label: Text(rotulo),
      selected: selecionado,
      onSelected: (sel) {
        if (sel) setState(() => _filtroStatus = rotulo);
      },
      selectedColor: corFundo.withOpacity(0.2),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selecionado
            ? corFundo.withRed(corFundo.red ~/ 1.5)
            : Colors.black54,
        fontSize: 11,
        fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Gestão de Insumos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar insumo, classe...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _limparFiltros,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _termoBusca = valor.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // FILTROS DE STATUS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _chipStatus('Ativos', Colors.green),
                    const SizedBox(width: 6),
                    _chipStatus('Inativos', Colors.red),
                    const SizedBox(width: 6),
                    _chipStatus('Todos', Colors.blueGrey),
                  ],
                ),
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // LISTA DE RESULTADOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('insumos')
                  .where('clienteId', isEqualTo: 'teste_textil')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum insumo cadastrado.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  );

                var documentos = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome'] ?? '').toString().toLowerCase();
                  final classe = (data['classe'] ?? '')
                      .toString()
                      .toLowerCase();
                  final subclasse = (data['subclasse'] ?? '')
                      .toString()
                      .toLowerCase();
                  final obs = (data['observacoes'] ?? '')
                      .toString()
                      .toLowerCase();
                  final ativo = data['ativo'] ?? true;

                  if (_filtroStatus == 'Ativos' && !ativo) return false;
                  if (_filtroStatus == 'Inativos' && ativo) return false;

                  bool matchBusca =
                      _termoBusca.isEmpty ||
                      nome.contains(_termoBusca) ||
                      classe.contains(_termoBusca) ||
                      subclasse.contains(_termoBusca) ||
                      obs.contains(_termoBusca);
                  return matchBusca;
                }).toList();

                if (documentos.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum resultado encontrado.',
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final data =
                        documentos[index].data() as Map<String, dynamic>;
                    final id = documentos[index].id;
                    final ativo = data['ativo'] ?? true;
                    final imagemBase64 = data['imagemBase64'];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: ativo ? Colors.white : Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail da Imagem
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
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
                                  : const Icon(
                                      Icons.inventory_2,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Dados do Insumo
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['nome'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      decoration: ativo
                                          ? TextDecoration.none
                                          : TextDecoration.lineThrough,
                                      color: ativo
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${data['classe'] ?? ''} > ${data['subclasse'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Unid: ${data['unidade'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (data['observacoes'] != null &&
                                          data['observacoes']
                                              .toString()
                                              .isNotEmpty)
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Botões de Ação
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blueGrey,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FormInsumo(
                                        insumoParaEditar: documentos[index],
                                      ),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: ativo,
                                  activeColor: Colors.blueGrey,
                                  onChanged: (valor) =>
                                      _alterarStatus(id, valor),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueGrey,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FormInsumo()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
