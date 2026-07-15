import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tela_ficha_tecnica_main.dart';
import 'form_produto.dart';

class AbaIdentificacaoComercial extends StatefulWidget {
  final TelaFichaTecnicaMainState controller;

  const AbaIdentificacaoComercial({super.key, required this.controller});

  @override
  State<AbaIdentificacaoComercial> createState() =>
      _AbaIdentificacaoComercialState();
}

class _AbaIdentificacaoComercialState extends State<AbaIdentificacaoComercial> {
  bool _carregandoBase = true;

  List<Map<String, dynamic>> _produtosList = [];
  List<Map<String, dynamic>> _gradesList = [];
  List<Map<String, dynamic>> _listaCoresBase = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();
  }

  Future<void> _carregarDadosBase({bool silent = false}) async {
    if (!silent) setState(() => _carregandoBase = true);
    try {
      final String empId = widget.controller.widget.empresaId;

      final prodSnap = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresa_id', isEqualTo: empId)
          .get();
      final gradesSnap = await FirebaseFirestore.instance
          .collection('grades')
          .get();
      final coresSnap = await FirebaseFirestore.instance
          .collection('cores')
          .get();

      setState(() {
        _produtosList = prodSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _gradesList = gradesSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _listaCoresBase = coresSnap.docs
            .where((d) {
              var data = d.data();
              return data['ativo'] == true || data['ativo'] == null;
            })
            .map((d) => {'id': d.id, ...d.data()})
            .toList();

        if (!silent) _carregandoBase = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar base na Aba 1: $e')),
        );
      }
      if (!silent) setState(() => _carregandoBase = false);
    }
  }

  void _modalNovoCadastroRapido(String colecao, String titulo, String hint) {
    String novoNome = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(labelText: 'Nome da Cor', hintText: hint),
          onChanged: (v) => novoNome = v,
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
            onPressed: () async {
              if (novoNome.trim().isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection(colecao).add({
                    'nome': novoNome.trim(),
                    'ativo': true,
                    'criadoEm': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                  _carregarDadosBase(silent: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$titulo criada com sucesso!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOTOR DE PESQUISA MODAL DO PRODUTO (Substitui o Dropdown)
  // =========================================================================
  void _abrirModalPesquisaProduto() {
    showDialog(
      context: context,
      builder: (context) {
        String termoPesquisaLocal = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filtra a lista de produtos na memória
            var produtosFiltrados = _produtosList.where((p) {
              final nome = (p['nome'] ?? '').toString().toLowerCase();
              final ref = (p['referencia'] ?? '').toString().toLowerCase();
              final busca = termoPesquisaLocal.toLowerCase();
              return nome.contains(busca) || ref.contains(busca);
            }).toList();

            return AlertDialog(
              title: const Text(
                'Pesquisar Produto Base',
                style: TextStyle(color: Colors.blueGrey),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome ou referência...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          termoPesquisaLocal = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: produtosFiltrados.isEmpty
                          ? const Center(
                              child: Text('Nenhum produto encontrado.'),
                            )
                          : ListView.builder(
                              itemCount: produtosFiltrados.length,
                              itemBuilder: (context, index) {
                                var p = produtosFiltrados[index];
                                return Card(
                                  elevation: 1,
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.checkroom,
                                      color: Colors.teal,
                                    ),
                                    title: Text(p['nome'] ?? ''),
                                    subtitle: Text(
                                      'Ref: ${p['referencia'] ?? 'S/R'}',
                                    ),
                                    onTap: () {
                                      setState(() {
                                        widget.controller.produtoSelecionadoId =
                                            p['id'];
                                        widget.controller.produtoNome =
                                            p['nome'];
                                        widget.controller.referencia =
                                            p['referencia'];
                                        widget.controller.registrarAlteracao();
                                      });
                                      Navigator.pop(context); // Fecha o modal
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // INTERFACE PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    if (_carregandoBase) {
      return const Center(child: CircularProgressIndicator());
    }

    Map<String, dynamic>? produtoDados;
    if (widget.controller.produtoSelecionadoId != null &&
        _produtosList.isNotEmpty) {
      try {
        produtoDados = _produtosList.firstWhere(
          (p) => p['id'] == widget.controller.produtoSelecionadoId,
        );
      } catch (_) {}
    }

    // Define o texto que aparece no campo "falso dropdown" de Produto
    String textoExibicaoProduto = 'Selecione um Produto...';
    if (produtoDados != null) {
      textoExibicaoProduto =
          '[${produtoDados['referencia'] ?? 'S/R'}] ${produtoDados['nome']}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Identidade do Produto: Defina o Modelo, Grade e Cores',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // --- NOVO COMPONENTE: PESQUISA MODAL DE PRODUTO ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _abrirModalPesquisaProduto,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Vincular Produto Base',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                      suffixIcon: Icon(
                        Icons.search,
                      ), // Ícone indicando que é clicável para buscar
                    ),
                    child: Text(
                      textoExibicaoProduto,
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.controller.produtoSelecionadoId == null
                            ? Colors.grey.shade600
                            : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 56,
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
                      MaterialPageRoute(
                        builder: (_) => FormProduto(
                          empresaId: widget.controller.widget.empresaId,
                        ),
                      ),
                    );
                    _carregarDadosBase(silent: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- GRADE (Mantido como Dropdown porque costumam ser poucas) ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vincular Grade (Tamanhos permitidos)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_size),
                  ),
                  value:
                      _gradesList.any(
                        (g) => g['id'] == widget.controller.gradeSelecionadaId,
                      )
                      ? widget.controller.gradeSelecionadaId
                      : null,
                  items: _gradesList.map((g) {
                    final tam = List<String>.from(g['tamanhos'] ?? []);
                    return DropdownMenuItem<String>(
                      value: g['id'],
                      child: Text(
                        '${g['nome']} (${tam.join('/')})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    var g = _gradesList.firstWhere((e) => e['id'] == val);
                    setState(() {
                      widget.controller.gradeSelecionadaId = val;
                      widget.controller.gradeNome = g['nome'];
                      widget.controller.tamanhosGrade = List<String>.from(
                        g['tamanhos'] ?? [],
                      );
                      widget.controller.registrarAlteracao();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Nova Grade',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, utilize o cadastro de grades no menu base por enquanto.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // --- CORES COMERCIAIS ---
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              border: Border.all(color: Colors.blueGrey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Variantes Comerciais (Cores Autorizadas)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blueGrey,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'O vendedor só poderá lançar pedidos nas cores que você ativar abaixo.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      tooltip: 'Nova Cor Rápida',
                      onPressed: () => _modalNovoCadastroRapido(
                        'cores',
                        'Cadastrar Nova Cor',
                        'Ex: Vermelho, Preto',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _listaCoresBase.isEmpty
                    ? const Text(
                        'Nenhuma cor encontrada no banco de dados.',
                        style: TextStyle(color: Colors.red),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _listaCoresBase.map((corDoc) {
                          String nomeCor = corDoc['nome'] ?? 'Sem Nome';
                          bool isSelected = widget
                              .controller
                              .coresComerciaisDisponiveis
                              .contains(nomeCor);
                          return FilterChip(
                            label: Text(
                              nomeCor,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.blueGrey.shade700,
                            checkmarkColor: Colors.white,
                            onSelected: (bool valor) {
                              setState(() {
                                if (valor) {
                                  widget.controller.coresComerciaisDisponiveis
                                      .add(nomeCor);
                                } else {
                                  widget.controller.coresComerciaisDisponiveis
                                      .remove(nomeCor);
                                }
                                widget.controller.registrarAlteracao();
                              });
                            },
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),

          // --- RESUMO COM FOTO (VITRINE) ---
          if (widget.controller.produtoSelecionadoId != null ||
              widget.controller.gradeSelecionadaId != null) ...[
            const SizedBox(height: 32),
            Card(
              color: Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade200),
                        image:
                            (produtoDados != null &&
                                produtoDados['fotoBase64'] != null &&
                                produtoDados['fotoBase64'].isNotEmpty)
                            ? DecorationImage(
                                image: MemoryImage(
                                  base64Decode(produtoDados['fotoBase64']),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          (produtoDados == null ||
                              produtoDados['fotoBase64'] == null ||
                              produtoDados['fotoBase64'].isEmpty)
                          ? const Icon(
                              Icons.inventory,
                              size: 40,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumo da Identidade:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                          const Divider(),
                          if (widget.controller.produtoSelecionadoId != null)
                            Text(
                              '📦 [${widget.controller.referencia}] ${widget.controller.produtoNome}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 4),
                          if (widget.controller.gradeSelecionadaId != null)
                            Text(
                              '📏 Grade: ${widget.controller.gradeNome} [ ${widget.controller.tamanhosGrade.join(' | ')} ]',
                              style: const TextStyle(fontSize: 14),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '🎨 Cores Ativas: ${widget.controller.coresComerciaisDisponiveis.isEmpty ? 'Nenhuma' : widget.controller.coresComerciaisDisponiveis.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
