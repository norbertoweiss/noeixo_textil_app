import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cor_model.dart';
import 'form_grade.dart';
import 'form_cor.dart';
import 'form_tecido.dart';
import 'form_unidade_medida.dart'; // AQUI ESTÁ A NOVA IMPORTAÇÃO

class TelaCadastrosBase extends StatefulWidget {
  const TelaCadastrosBase({super.key});

  @override
  State<TelaCadastrosBase> createState() => _TelaCadastrosBaseState();
}

class _TelaCadastrosBaseState extends State<TelaCadastrosBase>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _filtroGrades = 'Todos';
  String _filtroCores = 'Todos';
  String _filtroTecidos = 'Todos';
  String _filtroUnidades = 'Todos'; // NOVO FILTRO PARA AS UNIDADES

  @override
  void initState() {
    super.initState();
    // ATUALIZADO: De 3 para 4 abas
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Função para mudar Ativo/Inativo direto na nuvem
  Future<void> _alterarStatus(
    String colecao,
    String id,
    bool novoStatus,
  ) async {
    await FirebaseFirestore.instance.collection(colecao).doc(id).update({
      'ativo': novoStatus,
    });
  }

  void _abrirFormularioCor({CorModel? cor}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FormCor(corParaEditar: cor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueGrey,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueGrey,
          isScrollable:
              true, // IMPORTANTE: Permite deslizar as abas em telas pequenas
          tabs: const [
            Tab(text: 'Grades'),
            Tab(text: 'Cores'),
            Tab(text: 'Tecidos'),
            Tab(text: 'Unidades'), // NOVA ABA
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaGrades(),
          _buildAbaCores(),
          _buildAbaTecidos(),
          _buildAbaUnidades(), // NOVA VISTA
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueGrey,
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FormGrade()),
            );
          } else if (_tabController.index == 1) {
            _abrirFormularioCor();
          } else if (_tabController.index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FormTecido()),
            );
          } else if (_tabController.index == 3) {
            // NAVEGAÇÃO PARA O NOVO FORMULÁRIO DE UNIDADES
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FormUnidadeMedida(),
              ),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ==========================================
  // ABA 1: GRADES EM TEMPO REAL
  // ==========================================
  Widget _buildAbaGrades() {
    return Column(
      children: [
        _construirFiltro(
          valorAtual: _filtroGrades,
          aoMudar: (novo) => setState(() => _filtroGrades = novo),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('grades')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma grade cadastrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtroGrades == 'Ativos') return ativo;
                if (_filtroGrades == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;
                  final tamanhos = List<String>.from(data['tamanhos'] ?? []);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ativo
                            ? Colors.blueGrey
                            : Colors.grey[400],
                        child: const Icon(
                          Icons.straighten,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        data['nome'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: ativo
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          color: ativo ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      subtitle: Text('Tamanhos: ${tamanhos.join(" - ")}'),
                      trailing: Switch(
                        value: ativo,
                        activeColor: Colors.blueGrey,
                        onChanged: (valor) =>
                            _alterarStatus('grades', id, valor),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 2: CORES EM TEMPO REAL
  // ==========================================
  Widget _buildAbaCores() {
    return Column(
      children: [
        _construirFiltro(
          valorAtual: _filtroCores,
          aoMudar: (novo) => setState(() => _filtroCores = novo),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cores')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma cor cadastrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtroCores == 'Ativos') return ativo;
                if (_filtroCores == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;

                  final cor = CorModel(
                    id: id,
                    clienteId: data['clienteId'] ?? '',
                    codigo: data['codigo'] ?? '',
                    nome: data['nome'] ?? '',
                    ativo: ativo,
                    imagemBytes: data['imagemBase64'] != null
                        ? base64Decode(data['imagemBase64'])
                        : null,
                  );

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: cor.imagemBytes != null
                            ? MemoryImage(cor.imagemBytes!)
                            : null,
                        child: cor.imagemBytes == null
                            ? const Icon(Icons.palette, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        '[${cor.codigo}] ${cor.nome}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: ativo
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          color: ativo ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                            onPressed: () => _abrirFormularioCor(cor: cor),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) =>
                                _alterarStatus('cores', id, valor),
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
    );
  }

  // ==========================================
  // ABA 3: TECIDOS EM TEMPO REAL
  // ==========================================
  Widget _buildAbaTecidos() {
    return Column(
      children: [
        _construirFiltro(
          valorAtual: _filtroTecidos,
          aoMudar: (novo) => setState(() => _filtroTecidos = novo),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tecidos')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum tecido cadastrado.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtroTecidos == 'Ativos') return ativo;
                if (_filtroTecidos == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ativo
                            ? Colors.blueGrey[100]
                            : Colors.grey[200],
                        child: Icon(
                          Icons.texture,
                          color: ativo ? Colors.blueGrey : Colors.grey,
                        ),
                      ),
                      title: Text(
                        data['nome'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: ativo
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          color: ativo ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        '${data['tipoProcesso']}\nRendimento: ${data['rendimento']} m/kg  |  Largura: ${data['largura']} m',
                      ),
                      isThreeLine: true,
                      trailing: Switch(
                        value: ativo,
                        activeColor: Colors.blueGrey,
                        onChanged: (valor) =>
                            _alterarStatus('tecidos', id, valor),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 4 (NOVA): UNIDADES DE MEDIDA
  // ==========================================
  Widget _buildAbaUnidades() {
    return Column(
      children: [
        _construirFiltro(
          valorAtual: _filtroUnidades,
          aoMudar: (novo) => setState(() => _filtroUnidades = novo),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('unidades_medida')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma unidade cadastrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtroUnidades == 'Ativos') return ativo;
                if (_filtroUnidades == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ativo
                            ? Colors.blueGrey[100]
                            : Colors.grey[200],
                        child: Text(
                          (data['sigla'] ?? '').toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ativo ? Colors.blueGrey : Colors.grey,
                          ),
                        ),
                      ),
                      title: Text(
                        data['nome'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: ativo
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          color: ativo ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                            onPressed: () {
                              // NAVEGAÇÃO PARA O FORMULÁRIO DE UNIDADE NO MODO EDIÇÃO
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FormUnidadeMedida(
                                    unidadeParaEditar: documentos[index],
                                  ),
                                ),
                              );
                            },
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) =>
                                _alterarStatus('unidades_medida', id, valor),
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
    );
  }

  // Componente visual reutilizável para os botões de filtro
  Widget _construirFiltro({
    required String valorAtual,
    required Function(String) aoMudar,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Todos', label: Text('Todos')),
          ButtonSegment(value: 'Ativos', label: Text('Ativos')),
          ButtonSegment(value: 'Inativos', label: Text('Inativos')),
        ],
        selected: {valorAtual},
        onSelectionChanged: (Set<String> novaSelecao) =>
            aoMudar(novaSelecao.first),
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Colors.blueGrey,
        ),
      ),
    );
  }
}
