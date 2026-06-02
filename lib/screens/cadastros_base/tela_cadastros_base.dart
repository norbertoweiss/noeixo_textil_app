import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cor_model.dart';

// Importações dos formulários fixos da fábrica
import 'form_grade.dart';
import 'form_cor.dart';
import 'form_tecido.dart';
import 'form_unidade_medida.dart';

class TelaCadastrosBase extends StatefulWidget {
  const TelaCadastrosBase({super.key});

  @override
  State<TelaCadastrosBase> createState() => _TelaCadastrosBaseState();
}

class _TelaCadastrosBaseState extends State<TelaCadastrosBase> {
  // =========================================================================
  // MÓDULOS FIXOS (Os que têm formulários complexos específicos)
  // =========================================================================
  final List<Map<String, dynamic>> _modulosFixos = [
    {
      'id': 'grades',
      'titulo': 'Grades',
      'icone': Icons.format_size,
      'ativo': true,
    },
    {
      'id': 'cores',
      'titulo': 'Cores',
      'icone': Icons.color_lens,
      'ativo': true,
    },
    {
      'id': 'tecidos',
      'titulo': 'Tecidos',
      'icone': Icons.texture,
      'ativo': true,
    },
    {
      'id': 'unidades',
      'titulo': 'Unidades',
      'icone': Icons.straighten,
      'ativo': true,
    },
  ];

  // Filtros de estado por aba
  final Map<String, String> _filtrosAtivos = {
    'grades': 'Todos',
    'cores': 'Todos',
    'tecidos': 'Todos',
    'unidades': 'Todos',
  };

  List<Map<String, dynamic>> _modulosCustomizados = [];

  @override
  void initState() {
    super.initState();
    _ouvirModulosCustomizados();
  }

  // =========================================================================
  // MOTOR DE TABELAS LIVRES (Ouvinte do Firebase)
  // =========================================================================
  void _ouvirModulosCustomizados() {
    FirebaseFirestore.instance
        .collection('tabelas_auxiliares_config')
        .where('clienteId', isEqualTo: 'teste_textil')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _modulosCustomizados = snapshot.docs.map((doc) {
                var dados = doc.data();
                dados['id'] = doc.id;
                if (!_filtrosAtivos.containsKey(doc.id)) {
                  _filtrosAtivos[doc.id] = 'Todos';
                }
                return dados;
              }).toList();
            });
          }
        });
  }

  List<Map<String, dynamic>> get _todasAsAbas {
    List<Map<String, dynamic>> abas = [];
    abas.addAll(_modulosFixos.where((m) => m['ativo'] == true));
    abas.addAll(_modulosCustomizados.where((m) => m['ativo'] == true));
    return abas;
  }

  // =========================================================================
  // GESTÃO DE ESTADOS E CONFIGURAÇÕES
  // =========================================================================
  Future<void> _alterarStatusDocumento(
    String colecao,
    String id,
    bool novoStatus,
  ) async {
    await FirebaseFirestore.instance.collection(colecao).doc(id).update({
      'ativo': novoStatus,
    });
  }

  // Função para renomear as tabelas base já criadas
  void _renomearTabelaCustomizada(String idDoc, String nomeAtual) {
    final TextEditingController tituloCtrl = TextEditingController(
      text: nomeAtual,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Renomear Tabela',
          style: TextStyle(color: Colors.blueGrey),
        ),
        content: TextField(
          controller: tituloCtrl,
          decoration: const InputDecoration(
            labelText: 'Novo Nome da Tabela',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (tituloCtrl.text.trim().isNotEmpty &&
                  tituloCtrl.text.trim() != nomeAtual) {
                await FirebaseFirestore.instance
                    .collection('tabelas_auxiliares_config')
                    .doc(idDoc)
                    .update({
                      'titulo': tituloCtrl.text.trim(),
                      'dataAtualizacao': FieldValue.serverTimestamp(),
                    });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  void _abrirConfiguracaoModulos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestão de Tabelas Base',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Text(
                    'Ative ou desative abas, edite os nomes ou crie novas tabelas.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Tabelas Nativas do Sistema',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        StatefulBuilder(
                          builder: (context, setModalState) {
                            return Column(
                              children: _modulosFixos.map((modulo) {
                                return SwitchListTile(
                                  title: Text(modulo['titulo']),
                                  secondary: Icon(
                                    modulo['icone'],
                                    color: Colors.blueGrey,
                                  ),
                                  activeColor: Colors.blueGrey,
                                  value: modulo['ativo'],
                                  onChanged: (bool valor) {
                                    setModalState(
                                      () => modulo['ativo'] = valor,
                                    );
                                    setState(() {});
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Tabelas Customizadas da Fábrica',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        // O StreamBuilder aqui garante a visualização em Tempo Real na modal
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tabelas_auxiliares_config')
                              .where('clienteId', isEqualTo: 'teste_textil')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Nenhuma tabela customizada criada.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: snapshot.data!.docs.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                bool ativo = data['ativo'] ?? true;
                                return ListTile(
                                  title: Text(data['titulo'] ?? ''),
                                  leading: const Icon(
                                    Icons.list_alt,
                                    color: Colors.blueGrey,
                                  ),
                                  trailing: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      // O LÁPIS QUE FALTAVA!
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blueGrey,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _renomearTabelaCustomizada(
                                              doc.id,
                                              data['titulo'],
                                            ),
                                      ),
                                      Switch(
                                        activeColor: Colors.blueGrey,
                                        value: ativo,
                                        onChanged: (bool valor) async {
                                          await FirebaseFirestore.instance
                                              .collection(
                                                'tabelas_auxiliares_config',
                                              )
                                              .doc(doc.id)
                                              .update({'ativo': valor});
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('CRIAR NOVA TABELA (Ex: Estoques)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirDialogoNovaTabela();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // DIÁLOGO PARA CRIAR UMA NOVA ABA INTEIRA
  void _abrirDialogoNovaTabela() {
    final TextEditingController tituloCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Nova Tabela Auxiliar',
          style: TextStyle(color: Colors.blueGrey),
        ),
        content: TextField(
          controller: tituloCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome da Tabela (ex: Locais de Estoque)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (tituloCtrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('tabelas_auxiliares_config')
                    .add({
                      'clienteId': 'teste_textil',
                      'titulo': tituloCtrl.text.trim(),
                      'ativo': true,
                      'dataCriacao': FieldValue.serverTimestamp(),
                    });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('CRIAR TABELA'),
          ),
        ],
      ),
    );
  }

  // DIÁLOGO UNIFICADO: CRIA OU EDITA UM ITEM DENTRO DE UMA TABELA CUSTOMIZADA
  void _abrirDialogoItemCustomizado({
    required String idTabela,
    required String tituloTabela,
    String? idDoc,
    String? nomeAtual,
  }) {
    final TextEditingController nomeCtrl = TextEditingController(
      text: nomeAtual,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          idDoc == null
              ? 'Novo Registo em $tituloTabela'
              : 'Editar Registo em $tituloTabela',
          style: const TextStyle(color: Colors.blueGrey),
        ),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome (ex: Estoque A)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nomeCtrl.text.trim().isNotEmpty) {
                if (idDoc == null) {
                  // MODO INCLUSÃO
                  await FirebaseFirestore.instance
                      .collection('tabelas_auxiliares_dados')
                      .add({
                        'clienteId': 'teste_textil',
                        'tabelaId': idTabela,
                        'nome': nomeCtrl.text.trim(),
                        'ativo': true,
                        'dataCriacao': FieldValue.serverTimestamp(),
                      });
                } else {
                  // MODO EDIÇÃO
                  await FirebaseFirestore.instance
                      .collection('tabelas_auxiliares_dados')
                      .doc(idDoc)
                      .update({
                        'nome': nomeCtrl.text.trim(),
                        'dataAtualizacao': FieldValue.serverTimestamp(),
                      });
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(idDoc == null ? 'SALVAR' : 'ATUALIZAR'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CONSTRUTORES DE ABAS
  // =========================================================================
  Widget _construirFiltro(String chaveAba) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Todos', label: Text('Todos')),
          ButtonSegment(value: 'Ativos', label: Text('Ativos')),
          ButtonSegment(value: 'Inativos', label: Text('Inativos')),
        ],
        selected: {_filtrosAtivos[chaveAba] ?? 'Todos'},
        onSelectionChanged: (Set<String> novaSelecao) {
          setState(() {
            _filtrosAtivos[chaveAba] = novaSelecao.first;
          });
        },
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Colors.blueGrey,
        ),
      ),
    );
  }

  // Construtor para as Abas Customizadas (Com Lápis de Edição)
  Widget _buildAbaCustomizada(String idTabela, String tituloTabela) {
    return Column(
      children: [
        _construirFiltro(idTabela),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tabelas_auxiliares_dados')
                .where('clienteId', isEqualTo: 'teste_textil')
                .where('tabelaId', isEqualTo: idTabela)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text('Nenhum registo encontrado nesta tabela.'),
                );

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtrosAtivos[idTabela] == 'Ativos') return ativo;
                if (_filtrosAtivos[idTabela] == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  var data = documentos[index].data() as Map<String, dynamic>;
                  String idDoc = documentos[index].id;
                  bool ativo = data['ativo'] ?? true;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ativo
                            ? Colors.blueGrey[50]
                            : Colors.grey[200],
                        child: Icon(
                          Icons.folder_open,
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
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                            onPressed: () => _abrirDialogoItemCustomizado(
                              idTabela: idTabela,
                              tituloTabela: tituloTabela,
                              idDoc: idDoc,
                              nomeAtual: data['nome'] ?? '',
                            ),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) => _alterarStatusDocumento(
                              'tabelas_auxiliares_dados',
                              idDoc,
                              valor,
                            ),
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

  Widget _buildAbaGrades() {
    return Column(
      children: [
        _construirFiltro('grades'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('grades')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text('Nenhuma grade cadastrada.'));

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtrosAtivos['grades'] == 'Ativos') return ativo;
                if (_filtrosAtivos['grades'] == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;
                  final tamanhos = List<String>.from(data['tamanhos'] ?? []);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                                builder: (context) => FormGrade(
                                  gradeParaEditar: documentos[index],
                                ),
                              ),
                            ),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) =>
                                _alterarStatusDocumento('grades', id, valor),
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

  Widget _buildAbaCores() {
    return Column(
      children: [
        _construirFiltro('cores'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cores')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text('Nenhuma cor cadastrada.'));

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtrosAtivos['cores'] == 'Ativos') return ativo;
                if (_filtrosAtivos['cores'] == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                                builder: (context) =>
                                    FormCor(corParaEditar: cor),
                              ),
                            ),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) =>
                                _alterarStatusDocumento('cores', id, valor),
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

  Widget _buildAbaTecidos() {
    return Column(
      children: [
        _construirFiltro('tecidos'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tecidos')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text('Nenhum tecido cadastrado.'));

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtrosAtivos['tecidos'] == 'Ativos') return ativo;
                if (_filtrosAtivos['tecidos'] == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                        '${data['tipoProcesso']}\nRendimento: ${data['rendimento']} m/kg | Largura: ${data['largura']} m',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                                builder: (context) => FormTecido(
                                  tecidoParaEditar: documentos[index],
                                ),
                              ),
                            ),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) =>
                                _alterarStatusDocumento('tecidos', id, valor),
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

  Widget _buildAbaUnidades() {
    return Column(
      children: [
        _construirFiltro('unidades'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('unidades_medida')
                .where('clienteId', isEqualTo: 'teste_textil')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(child: Text('Nenhuma unidade cadastrada.'));

              var documentos = snapshot.data!.docs.where((doc) {
                bool ativo = doc['ativo'] ?? true;
                if (_filtrosAtivos['unidades'] == 'Ativos') return ativo;
                if (_filtrosAtivos['unidades'] == 'Inativos') return !ativo;
                return true;
              }).toList();

              return ListView.builder(
                itemCount: documentos.length,
                itemBuilder: (context, index) {
                  final data = documentos[index].data() as Map<String, dynamic>;
                  final id = documentos[index].id;
                  final ativo = data['ativo'] ?? true;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                                builder: (context) => FormUnidadeMedida(
                                  unidadeParaEditar: documentos[index],
                                ),
                              ),
                            ),
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) => _alterarStatusDocumento(
                              'unidades_medida',
                              id,
                              valor,
                            ),
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

  Widget _construirConteudoDaAba(Map<String, dynamic> abaDefinicao) {
    switch (abaDefinicao['id']) {
      case 'grades':
        return _buildAbaGrades();
      case 'cores':
        return _buildAbaCores();
      case 'tecidos':
        return _buildAbaTecidos();
      case 'unidades':
        return _buildAbaUnidades();
      default:
        return _buildAbaCustomizada(abaDefinicao['id'], abaDefinicao['titulo']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final abasAtuais = _todasAsAbas;

    return DefaultTabController(
      key: ValueKey(abasAtuais.length),
      length: abasAtuais.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueGrey,
          title: const Text(
            'Cadastros Base',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurar Tabelas',
              onPressed: _abrirConfiguracaoModulos,
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.blueGrey,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueGrey,
            isScrollable: true,
            tabs: abasAtuais
                .map(
                  (aba) => Tab(
                    icon: aba['icone'] != null
                        ? Icon(aba['icone'])
                        : const Icon(Icons.list_alt),
                    text: aba['titulo'],
                  ),
                )
                .toList(),
          ),
        ),
        body: TabBarView(
          children: abasAtuais
              .map((aba) => _construirConteudoDaAba(aba))
              .toList(),
        ),
        floatingActionButton: Builder(
          builder: (BuildContext innerContext) {
            return FloatingActionButton(
              backgroundColor: Colors.blueGrey,
              onPressed: () {
                final int abaIndex = DefaultTabController.of(
                  innerContext,
                ).index;
                final abaAtual = abasAtuais[abaIndex];

                if (abaAtual['id'] == 'grades') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FormGrade()),
                  );
                } else if (abaAtual['id'] == 'cores') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FormCor()),
                  );
                } else if (abaAtual['id'] == 'tecidos') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FormTecido()),
                  );
                } else if (abaAtual['id'] == 'unidades') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FormUnidadeMedida(),
                    ),
                  );
                } else {
                  // Abre o diálogo em modo de nova inclusão
                  _abrirDialogoItemCustomizado(
                    idTabela: abaAtual['id'],
                    tituloTabela: abaAtual['titulo'],
                  );
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}
