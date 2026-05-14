import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'form_produto.dart';

class FormFichaTecnica extends StatefulWidget {
  final String? fichaId;
  final Map<String, dynamic>? dadosAtuais;

  const FormFichaTecnica({super.key, this.fichaId, this.dadosAtuais});

  @override
  State<FormFichaTecnica> createState() => _FormFichaTecnicaState();
}

class _FormFichaTecnicaState extends State<FormFichaTecnica> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _carregandoBase = true;

  // RASTREADOR DE ALTERAÇÕES
  bool _houveAlteracao = false;

  // --- DADOS DA FICHA ---
  String? _produtoSelecionadoId;
  String? _produtoNome;
  String? _referencia;
  String? _gradeSelecionadaId;
  String? _gradeNome;
  List<String> _tamanhosGrade = [];

  List<Map<String, dynamic>> _insumosConsumidos = [];
  List<Map<String, dynamic>> _processosRoteiro = [];
  List<Map<String, dynamic>> _itensQualidade = []; // Aba 4

  // --- LISTAS PARA O AUTOCOMPLETE ---
  List<Map<String, dynamic>> _produtosList = [];
  List<Map<String, dynamic>> _gradesList = [];
  List<Map<String, dynamic>> _insumosBaseList = [];
  List<Map<String, dynamic>> _parametrosQualidadeBase = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();

    if (widget.dadosAtuais != null) {
      _produtoSelecionadoId = widget.dadosAtuais!['produtoId'];
      _produtoNome = widget.dadosAtuais!['produtoNome'];
      _referencia = widget.dadosAtuais!['referencia'];
      _gradeSelecionadaId = widget.dadosAtuais!['gradeId'];
      _gradeNome = widget.dadosAtuais!['gradeNome'];

      _tamanhosGrade = List<String>.from(widget.dadosAtuais!['tamanhos'] ?? []);
      _insumosConsumidos = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['insumos'] ?? [],
      );
      _processosRoteiro = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['processos'] ?? [],
      );
      _itensQualidade = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['qualidade'] ?? [],
      );
    }
  }

  Future<void> _carregarDadosBase() async {
    setState(() => _carregandoBase = true);
    try {
      final prodSnap = await FirebaseFirestore.instance
          .collection('produtos')
          .get();
      final gradesSnap = await FirebaseFirestore.instance
          .collection('grades')
          .get();
      final insumosSnap = await FirebaseFirestore.instance
          .collection('insumos')
          .get();
      final qualidadeSnap = await FirebaseFirestore.instance
          .collection('parametros_qualidade')
          .get();

      setState(() {
        _produtosList = prodSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _gradesList = gradesSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _insumosBaseList = insumosSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _parametrosQualidadeBase = qualidadeSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _carregandoBase = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar base: $e')));
      setState(() => _carregandoBase = false);
    }
  }

  Future<void> _salvarFicha() async {
    if (_produtoSelecionadoId == null || _gradeSelecionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um Produto e uma Grade.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final dados = {
      'produtoId': _produtoSelecionadoId,
      'produtoNome': _produtoNome,
      'referencia': _referencia,
      'gradeId': _gradeSelecionadaId,
      'gradeNome': _gradeNome,
      'tamanhos': _tamanhosGrade,
      'insumos': _insumosConsumidos,
      'processos': _processosRoteiro,
      'qualidade': _itensQualidade,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.fichaId == null) {
        dados['criadoEm'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('fichas_tecnicas')
            .add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('fichas_tecnicas')
            .doc(widget.fichaId)
            .update(dados);
      }

      _houveAlteracao = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ficha salva com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _avisarSaidaSemSalvar() async {
    if (!_houveAlteracao) return true;

    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção!', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Você tem alterações que não foram salvas. Se sair agora, perderá o trabalho feito. Deseja sair mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return sair ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: WillPopScope(
        onWillPop: _avisarSaidaSemSalvar,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.fichaId == null ? 'Nova Ficha Técnica' : 'Editar Ficha',
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(
                  right: 8.0,
                  top: 8.0,
                  bottom: 8.0,
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'SALVAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _salvarFicha,
                ),
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Identificação', icon: Icon(Icons.info_outline)),
                Tab(text: 'Insumos', icon: Icon(Icons.inventory_2_outlined)),
                Tab(text: 'Processos', icon: Icon(Icons.account_tree_outlined)),
                Tab(text: 'Qualidade', icon: Icon(Icons.verified_outlined)),
              ],
            ),
          ),
          body: _isLoading || _carregandoBase
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _abaIdentificacao(),
                    _abaInsumos(),
                    _abaProcessos(),
                    _abaQualidade(),
                  ],
                ),
        ),
      ),
    );
  }

  // =========================================================================
  // ABA 1: IDENTIFICAÇÃO
  // =========================================================================
  Widget _abaIdentificacao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vincule o Produto e a Grade Base aqui.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // --- PRODUTO ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                      text: _produtoNome != null
                          ? '$_referencia - $_produtoNome'
                          : '',
                    ),
                    displayStringForOption: (option) =>
                        '${option['referencia']} - ${option['nome']}',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _produtosList.where(
                        (p) =>
                            (p['nome']?.toString().toLowerCase().contains(
                                  query,
                                ) ??
                                false) ||
                            (p['referencia']?.toString().toLowerCase().contains(
                                  query,
                                ) ??
                                false),
                      );
                    },
                    onSelected: (selection) {
                      setState(() {
                        _produtoSelecionadoId = selection['id'];
                        _produtoNome = selection['nome'];
                        _referencia = selection['referencia'];
                        _houveAlteracao = true;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Buscar Produto (Ref ou Nome)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Novo Produto',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FormProduto()),
                      );
                      _carregarDadosBase();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- GRADE ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                      text: _gradeNome != null
                          ? '$_gradeNome (${_tamanhosGrade.join('/')})'
                          : '',
                    ),
                    displayStringForOption: (option) {
                      final tam = List<String>.from(option['tamanhos'] ?? []);
                      return '${option['nome']} (${tam.join('/')})';
                    },
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _gradesList.where((g) {
                        final nomeMatch =
                            g['nome']?.toString().toLowerCase().contains(
                              query,
                            ) ??
                            false;
                        final tamanhos = List<String>.from(g['tamanhos'] ?? []);
                        final tamanhoMatch = tamanhos.any(
                          (t) => t.toLowerCase().contains(query),
                        );
                        return nomeMatch || tamanhoMatch;
                      });
                    },
                    onSelected: (selection) {
                      setState(() {
                        _gradeSelecionadaId = selection['id'];
                        _gradeNome = selection['nome'];
                        _tamanhosGrade = List<String>.from(
                          selection['tamanhos'] ?? [],
                        );
                        _houveAlteracao = true;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Buscar Grade (Nome ou Tamanho)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.format_size),
                            ),
                          );
                        },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Nova Grade',
                    onPressed: _modalNovaGrade,
                  ),
                ),
              ],
            ),

            // --- RESUMO VINCULADO ---
            if (_produtoSelecionadoId != null ||
                _gradeSelecionadaId != null) ...[
              const SizedBox(height: 32),
              Card(
                color: Colors.blueGrey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ficha Vinculada a:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const Divider(),
                      if (_produtoSelecionadoId != null)
                        Text(
                          '📦 Produto: $_referencia - $_produtoNome',
                          style: const TextStyle(fontSize: 16),
                        ),
                      const SizedBox(height: 8),
                      if (_gradeSelecionadaId != null)
                        Text(
                          '📏 Grade: $_gradeNome [ ${_tamanhosGrade.join(' | ')} ]',
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _modalNovaGrade() {
    String nomeGrade = "";
    String tamanhosInput = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar Nova Grade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nome (Ex: Adulto Padrão)',
              ),
              onChanged: (v) => nomeGrade = v,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Tamanhos (separados por vírgula)',
                hintText: 'Ex: P, M, G, GG',
              ),
              onChanged: (v) => tamanhosInput = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomeGrade.isNotEmpty && tamanhosInput.isNotEmpty) {
                final listaTamanhos = tamanhosInput
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
                try {
                  await FirebaseFirestore.instance.collection('grades').add({
                    'nome': nomeGrade,
                    'tamanhos': listaTamanhos,
                    'criadoEm': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                  _carregarDadosBase();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grade criada!')),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              }
            },
            child: const Text('Salvar Grade'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ABA 2: INSUMOS
  // =========================================================================
  Widget _abaInsumos() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              'Adicionar Insumo à Ficha',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: () {
              if (_tamanhosGrade.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, selecione uma Grade na aba Identificação primeiro.',
                    ),
                  ),
                );
                return;
              }
              _modalAdicionarInsumo();
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _insumosConsumidos.length,
            itemBuilder: (context, index) {
              final item = _insumosConsumidos[index];

              String subtitulo = '';
              if (item['comportamento'] == 'fixo') {
                subtitulo =
                    'Quantidade: ${item['qtd_fixa']} ${item['unidade']}';
              } else if (item['comportamento'] == 'variavel') {
                subtitulo = 'Qtd Variável por Grade (${item['unidade']})';
              } else {
                subtitulo = 'Área CAD (${item['gramatura']} g/m²)';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Icon(
                      item['comportamento'] == 'cad'
                          ? Icons.architecture
                          : Icons.inventory_2,
                      color: Colors.blueGrey,
                    ),
                  ),
                  title: Text(
                    item['nome'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitulo),
                      if (item['perda'] > 0)
                        Text(
                          'Perda/Quebra: ${item['perda']}%',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      if (item['observacao'] != '')
                        Text(
                          'Obs: ${item['observacao']}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        tooltip: 'Editar Insumo',
                        onPressed: () =>
                            _modalAdicionarInsumo(indexEdicao: index),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Remover Insumo',
                        onPressed: () {
                          setState(() {
                            _insumosConsumidos.removeAt(index);
                            _houveAlteracao = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _modalAdicionarInsumo({int? indexEdicao}) {
    Map<String, dynamic>? insumoSelecionado;
    String comportamento = 'fixo';

    TextEditingController qtdFixaCtrl = TextEditingController();
    TextEditingController perdaCtrl = TextEditingController();
    TextEditingController obsCtrl = TextEditingController();
    TextEditingController gramaturaCtrl = TextEditingController();
    TextEditingController eficienciaCtrl = TextEditingController(text: '90');

    Map<String, TextEditingController> qtdVariavelCtrls = {};
    Map<String, TextEditingController> areasCadCtrls = {};

    for (var t in _tamanhosGrade) {
      qtdVariavelCtrls[t] = TextEditingController();
      areasCadCtrls[t] = TextEditingController();
    }

    if (indexEdicao != null) {
      final itemEditado = _insumosConsumidos[indexEdicao];
      insumoSelecionado = {
        'id': itemEditado['insumoId'],
        'nome': itemEditado['nome'],
        'unidade': itemEditado['unidade'],
      };

      comportamento = itemEditado['comportamento'] ?? 'fixo';
      qtdFixaCtrl.text = itemEditado['qtd_fixa']?.toString() ?? '';
      perdaCtrl.text = itemEditado['perda']?.toString() ?? '';
      obsCtrl.text = itemEditado['observacao'] ?? '';
      gramaturaCtrl.text = itemEditado['gramatura']?.toString() ?? '';
      eficienciaCtrl.text = itemEditado['eficiencia_risco']?.toString() ?? '90';

      if (comportamento == 'variavel') {
        final mapaVar =
            itemEditado['qtd_variavel'] as Map<String, dynamic>? ?? {};
        mapaVar.forEach((tamanho, valor) {
          if (qtdVariavelCtrls.containsKey(tamanho)) {
            qtdVariavelCtrls[tamanho]!.text = valor.toString();
          }
        });
      } else if (comportamento == 'cad') {
        final mapaCad = itemEditado['areas_cad'] as Map<String, dynamic>? ?? {};
        mapaCad.forEach((tamanho, valor) {
          if (areasCadCtrls.containsKey(tamanho)) {
            areasCadCtrls[tamanho]!.text = valor.toString();
          }
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            indexEdicao == null ? 'Configurar Insumo' : 'Editar Insumo',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                      text: insumoSelecionado?['nome'] ?? '',
                    ),
                    displayStringForOption: (option) =>
                        '${option['nome']} (${option['unidade'] ?? 'UN'})',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _insumosBaseList.where(
                        (i) =>
                            (i['nome']?.toString().toLowerCase().contains(
                              query,
                            ) ??
                            false),
                      );
                    },
                    onSelected: (selection) {
                      setModalState(() {
                        insumoSelecionado = selection;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Buscar Insumo do Estoque',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                  ),

                  if (insumoSelecionado != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Unidade de Medida: ${insumoSelecionado!['unidade'] ?? 'Não definida'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    value: comportamento,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Comportamento de Consumo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'fixo',
                        child: Text('Fixo por Peça (Ex: 1 Etiqueta)'),
                      ),
                      DropdownMenuItem(
                        value: 'variavel',
                        child: Text('Variável por Tamanho (Ex: Elástico)'),
                      ),
                      DropdownMenuItem(
                        value: 'cad',
                        child: Text('Cálculo de Área CAD (Para Malhas)'),
                      ),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        comportamento = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  if (comportamento == 'fixo') ...[
                    TextFormField(
                      controller: qtdFixaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ] else if (comportamento == 'variavel') ...[
                    const Text(
                      "Preencha a quantidade por tamanho:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _tamanhosGrade
                          .map(
                            (t) => SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: qtdVariavelCtrls[t],
                                decoration: InputDecoration(
                                  labelText: 'Tam $t',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ] else if (comportamento == 'cad') ...[
                    const Text(
                      "Preencha as Áreas do Molde (m²)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _tamanhosGrade
                          .map(
                            (t) => SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: areasCadCtrls[t],
                                decoration: InputDecoration(
                                  labelText: 'Tam $t (m²)',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: gramaturaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Gramatura (g/m²)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: eficienciaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Aprov. Risco (%)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: perdaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quebra/Perda (%)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: obsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Observação (Opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (insumoSelecionado == null && _insumosBaseList.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selecione um insumo da lista.'),
                    ),
                  );
                  return;
                }

                Map<String, double> mapaVariavel = {};
                Map<String, double> mapaCad = {};

                if (comportamento == 'variavel') {
                  qtdVariavelCtrls.forEach((key, ctrl) {
                    mapaVariavel[key] =
                        double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
                  });
                } else if (comportamento == 'cad') {
                  areasCadCtrls.forEach((key, ctrl) {
                    mapaCad[key] =
                        double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
                  });
                }

                final dadosInsumo = {
                  'insumoId': insumoSelecionado?['id'] ?? 'novo',
                  'nome': insumoSelecionado?['nome'] ?? 'Insumo Genérico',
                  'unidade': insumoSelecionado?['unidade'] ?? 'UN',
                  'comportamento': comportamento,
                  'qtd_fixa':
                      double.tryParse(qtdFixaCtrl.text.replaceAll(',', '.')) ??
                      0,
                  'qtd_variavel': mapaVariavel,
                  'areas_cad': mapaCad,
                  'gramatura':
                      double.tryParse(
                        gramaturaCtrl.text.replaceAll(',', '.'),
                      ) ??
                      0,
                  'eficiencia_risco':
                      double.tryParse(
                        eficienciaCtrl.text.replaceAll(',', '.'),
                      ) ??
                      90,
                  'perda':
                      double.tryParse(perdaCtrl.text.replaceAll(',', '.')) ?? 0,
                  'observacao': obsCtrl.text,
                };

                setState(() {
                  if (indexEdicao == null) {
                    _insumosConsumidos.add(dadosInsumo);
                  } else {
                    _insumosConsumidos[indexEdicao] = dadosInsumo;
                  }
                  _houveAlteracao = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Confirmar Insumo'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ABA 3: ROTEIRO DE PROCESSOS
  // =========================================================================
  Widget _abaProcessos() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Arraste para definir a ordem da produção",
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.construction, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'O módulo de Arrastar e Soltar processos entrará aqui.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ABA 4: QUALIDADE
  // =========================================================================
  Widget _abaQualidade() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              if (_tamanhosGrade.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Selecione uma Grade na Aba Identificação primeiro!',
                    ),
                  ),
                );
                return;
              }
              _modalAdicionarQualidade();
            },
            icon: const Icon(Icons.add_task),
            label: const Text('Adicionar Requisito de Qualidade'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _itensQualidade.length,
            itemBuilder: (context, index) {
              final item = _itensQualidade[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading:
                      item['fotoBase64'] != null &&
                          item['fotoBase64'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            base64Decode(item['fotoBase64'].toString()),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                  title: Text(
                    item['parametro'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Especificação: ${item['valor']} (${item['tolerancia']})',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _itensQualidade.removeAt(index);
                        _houveAlteracao = true;
                      });
                    },
                  ),
                  onTap: () => _modalAdicionarQualidade(indexEdicao: index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _modalAdicionarQualidade({int? indexEdicao}) {
    String parametro = '';
    final TextEditingController valorCtrl = TextEditingController();

    // NOTA TÉCNICA: O acento em "tolerânciaCtrl" foi removido para evitar
    // erros de compilação no linter do Flutter.
    final TextEditingController toleranciaCtrl = TextEditingController();

    String? fotoBase64;

    if (indexEdicao != null) {
      final item = _itensQualidade[indexEdicao];
      parametro = item['parametro']?.toString() ?? '';
      valorCtrl.text = item['valor']?.toString() ?? '';
      toleranciaCtrl.text = item['tolerancia']?.toString() ?? '';
      fotoBase64 = item['fotoBase64'];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            indexEdicao == null ? 'Novo Item de Qualidade' : 'Editar Qualidade',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<Map<String, dynamic>>(
                  initialValue: TextEditingValue(text: parametro),

                  // TIPAGEM CORRIGIDA PARA EVITAR ERROS: Forçamos a saída como String
                  displayStringForOption: (Map<String, dynamic> option) =>
                      option['nome'].toString(),

                  optionsBuilder: (TextEditingValue v) {
                    if (v.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    return _parametrosQualidadeBase.where(
                      (p) => p['nome'].toString().toLowerCase().contains(
                        v.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (Map<String, dynamic> s) {
                    parametro = s['nome'].toString();
                  },
                  fieldViewBuilder:
                      (
                        BuildContext ctx,
                        TextEditingController ctrl,
                        FocusNode focus,
                        VoidCallback submit,
                      ) {
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            labelText: 'Parâmetro (Ex: Largura da Barra)',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor Esperado',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: toleranciaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tolerância (+/-)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // --- CAPTURA DE FOTO PADRÃO ---
                const Text(
                  'Foto do Padrão Visual:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (fotoBase64 != null && fotoBase64!.isNotEmpty)
                  Image.memory(base64Decode(fotoBase64!), height: 120),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        final img = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 50,
                        );
                        if (img != null) {
                          final bytes = await img.readAsBytes();
                          setModalState(() {
                            fotoBase64 = base64Encode(bytes);
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () async {
                        final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 50,
                        );
                        if (img != null) {
                          final bytes = await img.readAsBytes();
                          setModalState(() {
                            fotoBase64 = base64Encode(bytes);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final novoItem = {
                  'parametro': parametro,
                  'valor': valorCtrl.text,
                  'tolerancia': toleranciaCtrl.text,
                  'fotoBase64': fotoBase64,
                };

                setState(() {
                  if (indexEdicao == null) {
                    _itensQualidade.add(novoItem);
                  } else {
                    _itensQualidade[indexEdicao] = novoItem;
                  }
                  _houveAlteracao = true;
                });

                Navigator.pop(context);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}
