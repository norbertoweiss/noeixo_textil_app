import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORTANTE: Certifique-se de importar o seu form de produtos
import 'form_produto.dart';

class FormFichaTecnica extends StatefulWidget {
  final String? fichaId;
  final Map<String, dynamic>? dadosAtuais;

  const FormFichaTecnica({Key? key, this.fichaId, this.dadosAtuais})
    : super(key: key);

  @override
  _FormFichaTecnicaState createState() => _FormFichaTecnicaState();
}

class _FormFichaTecnicaState extends State<FormFichaTecnica> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _carregandoBase = true;

  // Cabeçalho
  String? _produtoSelecionadoId;
  String? _produtoNome;
  String? _referencia;
  String? _gradeSelecionadaId;
  String? _gradeNome;
  List<String> _tamanhosGrade = [];

  // Listas de Dados Dinâmicos
  List<Map<String, dynamic>> _insumosConsumidos = [];
  List<Map<String, dynamic>> _processosRoteiro = [];

  // Listas para o Autocomplete
  List<Map<String, dynamic>> _produtosList = [];
  List<Map<String, dynamic>> _gradesList = [];

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
    }
  }

  // Busca todos os produtos e grades do Firebase para alimentar a pesquisa
  Future<void> _carregarDadosBase() async {
    setState(() => _carregandoBase = true);
    try {
      final prodSnap = await FirebaseFirestore.instance
          .collection('produtos')
          .get();
      // NOTA: Se as suas grades estiverem numa coleção com nome diferente de 'grades', ajuste abaixo
      final gradesSnap = await FirebaseFirestore.instance
          .collection('grades')
          .get();

      setState(() {
        _produtosList = prodSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _gradesList = gradesSnap.docs
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ficha salva com sucesso!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.fichaId == null ? 'Nova Ficha Técnica' : 'Editar Ficha',
          ),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _salvarFicha),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Identificação', icon: Icon(Icons.info_outline)),
              Tab(text: 'Insumos', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'Processos', icon: Icon(Icons.account_tree_outlined)),
            ],
          ),
        ),
        body: _isLoading || _carregandoBase
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [_abaIdentificacao(), _abaInsumos(), _abaProcessos()],
              ),
      ),
    );
  }

  // --- ABA 1: IDENTIFICAÇÃO ---
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

            // ----- PESQUISA DE PRODUTO -----
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
                      if (textEditingValue.text == '')
                        return const Iterable<Map<String, dynamic>>.empty();
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
                      // Vai para a tela de Produto, quando voltar recarrega a lista
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

            // ----- PESQUISA DE GRADE -----
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
                      if (textEditingValue.text == '')
                        return const Iterable<Map<String, dynamic>>.empty();
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

            // Resumo Visual da Seleção
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

  // --- MODAL PARA CRIAR NOVA GRADE RAPIDAMENTE ---
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
                  Navigator.pop(context); // Fecha o modal
                  _carregarDadosBase(); // Atualiza as listas do Autocomplete
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grade criada!')),
                  );
                } catch (e) {
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

  // --- ABA 2: INSUMOS E MOTOR DE CÁLCULO CAD ---
  Widget _abaInsumos() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Tecido/Insumo'),
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
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.texture, color: Colors.indigo),
                  title: Text(item['nome']),
                  subtitle: Text(
                    item['tipo_calculo'] == 'cad'
                        ? 'Cálculo por Área CAD'
                        : 'Peso Médio',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        setState(() => _insumosConsumidos.removeAt(index)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _modalAdicionarInsumo() {
    String nomeInsumo = "";
    String tipoCalculo = "peso";
    double gramatura = 0;
    double eficiencia = 90.0;
    Map<String, double> areasPorTamanho = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Configurar Insumo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nome do Tecido',
                  ),
                  onChanged: (v) => nomeInsumo = v,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: tipoCalculo,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Método de Custeio',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'peso',
                      child: Text('Peso Médio / Padrão'),
                    ),
                    DropdownMenuItem(
                      value: 'cad',
                      child: Text('Cálculo por Área CAD (Precisão)'),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => tipoCalculo = v!),
                ),
                if (tipoCalculo == 'cad') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    "Preencha as Áreas do Molde (m²)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  ..._tamanhosGrade
                      .map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Tamanho $t',
                              suffixText: 'm²',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => areasPorTamanho[t] =
                                double.tryParse(v.replaceAll(',', '.')) ?? 0,
                          ),
                        ),
                      )
                      .toList(),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Gramatura do Tecido (g/m²)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => gramatura = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Aproveitamento Risco (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => eficiencia = double.tryParse(v) ?? 90,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _insumosConsumidos.add({
                    'nome': nomeInsumo,
                    'tipo_calculo': tipoCalculo,
                    'areas': areasPorTamanho,
                    'gramatura': gramatura,
                    'eficiencia': eficiencia,
                  });
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

  // --- ABA 3: ROTEIRO DE PROCESSOS ---
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
}
