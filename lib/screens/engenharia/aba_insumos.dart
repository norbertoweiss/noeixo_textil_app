import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tela_ficha_tecnica_main.dart'; // Precisa conhecer o Cérebro

class AbaInsumos extends StatefulWidget {
  final TelaFichaTecnicaMainState controller;

  const AbaInsumos({super.key, required this.controller});

  @override
  State<AbaInsumos> createState() => _AbaInsumosState();
}

class _AbaInsumosState extends State<AbaInsumos> {
  bool _carregandoBase = true;
  List<Map<String, dynamic>> _insumosBaseList = [];
  List<Map<String, dynamic>> _listaProdutosIntermediarios = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();
  }

  Future<void> _carregarDadosBase() async {
    setState(() => _carregandoBase = true);
    try {
      final String empId = widget.controller.widget.empresaId;

      // Busca insumos da árvore geral
      final insumosSnap = await FirebaseFirestore.instance
          .collection('insumos')
          .get();

      // Busca peças pai (produtos intermediários) da empresa
      final prodSnap = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresa_id', isEqualTo: empId)
          .get();

      setState(() {
        _insumosBaseList = insumosSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        final todosProdutos = prodSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _listaProdutosIntermediarios = todosProdutos
            .where((p) => p['tipo'] == 'Produto Intermediário')
            .toList();

        _carregandoBase = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar base de insumos: $e')),
        );
      setState(() => _carregandoBase = false);
    }
  }

  void _modalAdicionarInsumo({int? indexEdicao}) {
    Map<String, dynamic>? insumoSelecionado;
    String comportamento = 'fixo';
    String tipoOrigem = 'Insumo Puro';

    TextEditingController qtdFixaCtrl = TextEditingController();
    TextEditingController perdaCtrl = TextEditingController();
    TextEditingController obsCtrl = TextEditingController();
    TextEditingController gramaturaCtrl = TextEditingController();
    TextEditingController eficienciaCtrl = TextEditingController(text: '90');
    Map<String, TextEditingController> qtdVariavelCtrls = {};
    Map<String, TextEditingController> areasCadCtrls = {};

    // O pulo do gato: puxa os tamanhos que o utilizador marcou na Aba 1
    for (var t in widget.controller.tamanhosGrade) {
      qtdVariavelCtrls[t] = TextEditingController();
      areasCadCtrls[t] = TextEditingController();
    }

    if (indexEdicao != null) {
      final itemEditado = widget.controller.insumosConsumidos[indexEdicao];
      tipoOrigem = itemEditado['tipoOrigem'] ?? 'Insumo Puro';
      insumoSelecionado = {
        'id': itemEditado['insumoId'],
        'nome': itemEditado['nome'],
        'unidade': itemEditado['unidade'],
        'referencia': itemEditado['referencia'],
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
          if (qtdVariavelCtrls.containsKey(tamanho))
            qtdVariavelCtrls[tamanho]!.text = valor.toString();
        });
      } else if (comportamento == 'cad') {
        final mapaCad = itemEditado['areas_cad'] as Map<String, dynamic>? ?? {};
        mapaCad.forEach((tamanho, valor) {
          if (areasCadCtrls.containsKey(tamanho))
            areasCadCtrls[tamanho]!.text = valor.toString();
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            indexEdicao == null
                ? 'Configurar Componente da Receita'
                : 'Editar Componente',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Insumo Básico'),
                        selected: tipoOrigem == 'Insumo Puro',
                        onSelected: (val) {
                          if (val)
                            setModalState(() {
                              tipoOrigem = 'Insumo Puro';
                              insumoSelecionado = null;
                            });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Peça Pai / Intermediário'),
                        selected: tipoOrigem == 'Produto Intermediário',
                        onSelected: (val) {
                          if (val)
                            setModalState(() {
                              tipoOrigem = 'Produto Intermediário';
                              insumoSelecionado = null;
                            });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                      text: insumoSelecionado?['nome'] ?? '',
                    ),
                    displayStringForOption: (option) =>
                        tipoOrigem == 'Insumo Puro'
                        ? '${option['nome']} (${option['unidade'] ?? 'UN'})'
                        : '[REF: ${option['referencia'] ?? 'S/R'}] ${option['nome']}',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty)
                        return const Iterable<Map<String, dynamic>>.empty();
                      final query = textEditingValue.text.toLowerCase();
                      final listaAlvo = tipoOrigem == 'Insumo Puro'
                          ? _insumosBaseList
                          : _listaProdutosIntermediarios;
                      return listaAlvo.where(
                        (i) =>
                            (i['nome']?.toString().toLowerCase().contains(
                                  query,
                                ) ??
                                false) ||
                            (i['referencia']?.toString().toLowerCase().contains(
                                  query,
                                ) ??
                                false),
                      );
                    },
                    onSelected: (selection) =>
                        setModalState(() => insumoSelecionado = selection),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: tipoOrigem == 'Insumo Puro'
                                  ? 'Buscar Insumo do Estoque'
                                  : 'Buscar Peça Pai do Estoque',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.search),
                            ),
                          );
                        },
                  ),
                  if (insumoSelecionado != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tipoOrigem == 'Insumo Puro'
                          ? 'Unidade de Medida: ${insumoSelecionado!['unidade'] ?? 'Não definida'}'
                          : 'Consumo Lógico: A peça consome outra sub-receita.',
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
                        child: Text(
                          'Fixo por Peça (Ex: 1 Etiqueta ou 1 Peça Pai)',
                        ),
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
                    onChanged: (v) => setModalState(() => comportamento = v!),
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
                      children: widget.controller.tamanhosGrade
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
                      children: widget.controller.tamanhosGrade
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
                if (insumoSelecionado == null) {
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
                  'tipoOrigem': tipoOrigem,
                  'insumoId': insumoSelecionado?['id'] ?? 'novo',
                  'nome': insumoSelecionado?['nome'] ?? 'Insumo Genérico',
                  'unidade': insumoSelecionado?['unidade'] ?? 'UN',
                  'referencia': insumoSelecionado?['referencia'] ?? '',
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

                // --- ATUALIZA O CÉREBRO E FORÇA A TELA A REENHAR ---
                setState(() {
                  if (indexEdicao == null) {
                    widget.controller.insumosConsumidos.add(dadosInsumo);
                  } else {
                    widget.controller.insumosConsumidos[indexEdicao] =
                        dadosInsumo;
                  }
                });
                widget.controller.registrarAlteracao();

                Navigator.pop(context);
              },
              child: const Text('Confirmar Insumo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoBase)
      return const Center(child: CircularProgressIndicator());

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
              'Adicionar Insumo ou Peça Pai',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: () {
              if (widget.controller.tamanhosGrade.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Selecione uma Grade na Aba 1 (Identificação) primeiro.',
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
          child: widget.controller.insumosConsumidos.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum componente adicionado à receita.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.controller.insumosConsumidos.length,
                  itemBuilder: (context, index) {
                    final item = widget.controller.insumosConsumidos[index];
                    String subtitulo = '';
                    if (item['comportamento'] == 'fixo')
                      subtitulo =
                          'Quantidade: ${item['qtd_fixa']} ${item['unidade']}';
                    else if (item['comportamento'] == 'variavel')
                      subtitulo = 'Qtd Variável por Grade (${item['unidade']})';
                    else
                      subtitulo = 'Área CAD (${item['gramatura']} g/m²)';

                    bool isPecaPai =
                        item['tipoOrigem'] == 'Produto Intermediário';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPecaPai
                              ? Colors.indigo.shade100
                              : Colors.blueGrey.shade100,
                          child: Icon(
                            isPecaPai
                                ? Icons.widgets
                                : (item['comportamento'] == 'cad'
                                      ? Icons.architecture
                                      : Icons.inventory_2),
                            color: isPecaPai ? Colors.indigo : Colors.blueGrey,
                          ),
                        ),
                        title: Text(
                          item['nome'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPecaPai)
                              const Text(
                                'SUB-RECEITA (PEÇA PAI)',
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueGrey,
                              ),
                              tooltip: 'Editar Componente',
                              onPressed: () =>
                                  _modalAdicionarInsumo(indexEdicao: index),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Remover',
                              onPressed: () {
                                setState(() {
                                  widget.controller.insumosConsumidos.removeAt(
                                    index,
                                  );
                                });
                                widget.controller.registrarAlteracao();
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
}
