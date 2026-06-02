import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaGestaoTabelaPreco extends StatefulWidget {
  final String empresaId;
  final String tabelaId; // Ex: 'tabela_padrao'
  final String nomeTabela;

  const TelaGestaoTabelaPreco({
    super.key,
    required this.empresaId,
    required this.tabelaId,
    required this.nomeTabela,
  });

  @override
  State<TelaGestaoTabelaPreco> createState() => _TelaGestaoTabelaPrecoState();
}

class _TelaGestaoTabelaPrecoState extends State<TelaGestaoTabelaPreco> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _produtos = [];

  // Controladores para edição individual
  final Map<String, TextEditingController> _precoControllers = {};

  // Filtros de exibição
  String _termoBusca = '';
  String _categoriaSelecionada = 'Todos';
  List<String> _categorias = ['Todos'];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // =========================================================================
  // CARREGAMENTO DE PRODUTOS E PREÇOS ATUAIS
  // =========================================================================
  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      final produtosSnap = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('tipo', isEqualTo: 'Produto Acabado')
          .get();

      final tabelaSnap = await FirebaseFirestore.instance
          .collection('tabelas_preco')
          .doc(widget.tabelaId)
          .collection('itens')
          .get();

      Map<String, double> precosAtuais = {};
      for (var doc in tabelaSnap.docs) {
        precosAtuais[doc.id] =
            double.tryParse(doc.data()['preco']?.toString() ?? '0') ?? 0.0;
      }

      Set<String> catSet = {'Todos'};
      List<Map<String, dynamic>> listaTemp = [];

      for (var doc in produtosSnap.docs) {
        final data = doc.data();
        String cat = data['categoria']?.toString().trim() ?? 'Sem Categoria';
        if (cat.isNotEmpty) catSet.add(cat);

        double precoAtual = precosAtuais[doc.id] ?? 0.0;

        listaTemp.add({
          'id': doc.id,
          'referencia': data['referencia'] ?? '',
          'nome': data['nome'] ?? '',
          'categoria': cat,
          'preco_atual': precoAtual,
        });

        _precoControllers[doc.id] = TextEditingController(
          text: precoAtual > 0 ? precoAtual.toStringAsFixed(2) : '',
        );
      }

      setState(() {
        _produtos = listaTemp;
        _categorias = catSet.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // MOTOR DE AJUSTE PERCENTUAL (DINÂMICO) COM PROTEÇÃO DE MARGEM
  // =========================================================================
  void _abrirModalAjusteEmMassa() {
    double percentual = 0.0;
    String escopo = 'Todos';
    String regraArredondamento = 'Exato (Matemático)';
    String centavosPersonalizados = '90'; // Valor inicial para o campo dinâmico

    final List<String> opcoesArredondamento = [
      'Exato (Matemático)',
      'Inteiro (Proteger Margem 1%)',
      'Terminar em centavos específicos', // <-- Nova opção dinâmica
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Ajuste Percentual em Massa'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Aumente ou diminua os preços com inteligência de arredondamento.',
                    ),
                    const SizedBox(height: 16),

                    // 1. Seleção do Escopo
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Aplicar em:',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      value: escopo,
                      items: _categorias
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c == 'Todos' ? 'Toda a Tabela' : 'Grupo: $c',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() => escopo = val!),
                    ),
                    const SizedBox(height: 16),

                    // 2. Regra de Estratégia
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Estratégia de Preço:',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      value: regraArredondamento,
                      items: opcoesArredondamento
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => regraArredondamento = val!),
                    ),
                    const SizedBox(height: 16),

                    // 3. CAMPO DINÂMICO (Só aparece se o gestor quiser escolher os centavos)
                    if (regraArredondamento ==
                        'Terminar em centavos específicos') ...[
                      TextFormField(
                        initialValue: centavosPersonalizados,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Quais centavos? (Ex: 99, 90, 85)',
                          prefixText: 'R\$ X,',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        onChanged: (val) => centavosPersonalizados = val,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. Valor do Percentual
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Percentual (%)',
                        hintText: 'Ex: 10 para aumentar, -5 para baixar',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.percent),
                        isDense: true,
                      ),
                      onChanged: (val) => percentual =
                          double.tryParse(val.replaceAll(',', '.')) ?? 0.0,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _aplicarPercentualNaMemoria(
                      percentual,
                      escopo,
                      regraArredondamento,
                      centavosPersonalizados,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar na Tela'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _aplicarPercentualNaMemoria(
    double percentual,
    String escopo,
    String regra,
    String centavosTxt,
  ) {
    if (percentual == 0) return;

    double fator = 1 + (percentual / 100);

    setState(() {
      for (var prod in _produtos) {
        if (escopo == 'Todos' || prod['categoria'] == escopo) {
          double valorAtual =
              double.tryParse(
                _precoControllers[prod['id']]!.text.replaceAll(',', '.'),
              ) ??
              0.0;

          if (valorAtual > 0) {
            double novoValor = valorAtual * fator;

            // --- APLICAÇÃO DA PSICOLOGIA DE PREÇOS DINÂMICA ---
            if (regra == 'Inteiro (Proteger Margem 1%)') {
              double valorAbaixo = novoValor.floorToDouble();
              double perdaPercentual =
                  ((novoValor - valorAbaixo) / novoValor) * 100;

              if (perdaPercentual >= 1.0) {
                novoValor = novoValor.ceilToDouble();
              } else {
                novoValor = valorAbaixo;
              }
            } else if (regra == 'Terminar em centavos específicos') {
              // Pega o número inteiro (Ex: 27,34 vira 27,00)
              double baseInteira = novoValor.truncateToDouble();

              // Converte a string digitada pelo gestor para decimal (Ex: "99" vira 0.99)
              int centavos = int.tryParse(centavosTxt) ?? 0;
              double fracaoCentavos = centavos / 100;

              // Soma a base com os novos centavos livres
              novoValor = baseInteira + fracaoCentavos;
            }

            _precoControllers[prod['id']]!.text = novoValor.toStringAsFixed(2);
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ajuste de $percentual% aplicado! Lembre-se de Gravar.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // =========================================================================
  // SALVAR TUDO (LOTE NO FIREBASE)
  // =========================================================================
  Future<void> _gravarTabelaNoBanco() async {
    setState(() => _isLoading = true);
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference tabelaRef = firestore
          .collection('tabelas_preco')
          .doc(widget.tabelaId);

      batch.set(tabelaRef, {
        'nome': widget.nomeTabela,
        'empresa_id': widget.empresaId,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (var prod in _produtos) {
        String prodId = prod['id'];
        double precoDigitado =
            double.tryParse(
              _precoControllers[prodId]!.text.replaceAll(',', '.'),
            ) ??
            0.0;

        if (precoDigitado > 0) {
          DocumentReference itemRef = tabelaRef.collection('itens').doc(prodId);
          batch.set(itemRef, {
            'preco': precoDigitado,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tabela gravada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gravar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // INTERFACE
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    var produtosFiltrados = _produtos.where((p) {
      bool atendeBusca =
          _termoBusca.isEmpty ||
          p['nome'].toLowerCase().contains(_termoBusca) ||
          p['referencia'].toLowerCase().contains(_termoBusca);
      bool atendeCat =
          _categoriaSelecionada == 'Todos' ||
          p['categoria'] == _categoriaSelecionada;
      return atendeBusca && atendeCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão: ${widget.nomeTabela}'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.percent),
            tooltip: 'Ajuste em Massa',
            onPressed: _abrirModalAjusteEmMassa,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Gravar Tabela'),
              onPressed: _gravarTabelaNoBanco,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Buscar referência ou modelo...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) =>
                              setState(() => _termoBusca = val.toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Grupo / Categoria',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          value: _categoriaSelecionada,
                          items: _categorias
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _categoriaSelecionada = val!),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.grey.shade200,
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Ref',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Produto',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Grupo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Preço (R\$)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: produtosFiltrados.length,
                    itemBuilder: (context, index) {
                      final prod = produtosFiltrados[index];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                prod['referencia'],
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                prod['nome'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(flex: 2, child: Text(prod['categoria'])),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _precoControllers[prod['id']],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
