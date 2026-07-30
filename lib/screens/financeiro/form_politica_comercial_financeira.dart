import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormPoliticaComercialFinanceira extends StatefulWidget {
  final String empresaId;
  final String? politicaId;
  final Map<String, dynamic>? dadosAtuais;

  const FormPoliticaComercialFinanceira({
    super.key,
    required this.empresaId,
    this.politicaId,
    this.dadosAtuais,
  });

  @override
  State<FormPoliticaComercialFinanceira> createState() =>
      _FormPoliticaComercialFinanceiraState();
}

class _FormPoliticaComercialFinanceiraState
    extends State<FormPoliticaComercialFinanceira> {
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  // --- DADOS PRINCIPAIS ---
  late TextEditingController _nomeController;
  bool _ativo = true;

  // --- REGRAS DE DESCONTO ---
  late TextEditingController _descontoMaximoController;
  String _acaoAoUltrapassarDesconto = 'Bloquear Venda';

  // --- REGRAS DE COMISSÃO ---
  String _tipoComissao = 'Fixa';
  late TextEditingController _comissaoFixaController;
  List<Map<String, TextEditingController>> _faixasComissao = [];

  // --- REGRAS DE MODIFICADORES DE PRAZO (BLOCO 4) ---
  final Map<String, Map<String, TextEditingController>>
  _modificadoresPagamento = {};
  String?
  _condicaoPagamentoSelecionada; // <-- NOVA VARIÁVEL PARA A LISTA SUSPENSA

  // --- REGRAS DE VOLUME DE PEDIDO (BLOCO 5) ---
  List<Map<String, TextEditingController>> _faixasVolume = [];

  @override
  void initState() {
    super.initState();

    _nomeController = TextEditingController();
    _descontoMaximoController = TextEditingController(text: '0.0');
    _comissaoFixaController = TextEditingController(text: '0.0');

    if (widget.dadosAtuais != null) {
      final dados = widget.dadosAtuais!;

      _nomeController.text = dados['nome_politica'] ?? '';
      _ativo = dados['ativo'] ?? true;
      _descontoMaximoController.text =
          (dados['desconto_maximo_permitido'] ?? 0.0).toString();
      _acaoAoUltrapassarDesconto =
          dados['acao_extrapolacao'] ?? 'Bloquear Venda';
      _tipoComissao = dados['tipo_comissao'] ?? 'Fixa';
      _comissaoFixaController.text = (dados['comissao_fixa'] ?? 0.0).toString();

      if (_tipoComissao == 'Escalonada' &&
          dados['faixas_escalonadas'] != null) {
        List faixas = dados['faixas_escalonadas'];
        for (var f in faixas) {
          _faixasComissao.add({
            'descInicial': TextEditingController(
              text: (f['desconto_inicial'] ?? 0.0).toString(),
            ),
            'descFinal': TextEditingController(
              text: (f['desconto_final'] ?? 0.0).toString(),
            ),
            'comissao': TextEditingController(
              text: (f['percentual_comissao'] ?? 0.0).toString(),
            ),
          });
        }
      }

      if (dados['modificadores_pagamento'] != null) {
        Map<String, dynamic> mods = dados['modificadores_pagamento'];
        mods.forEach((key, value) {
          _modificadoresPagamento[key] = {
            'comissao': TextEditingController(
              text: (value['comissao'] ?? 0.0).toString(),
            ),
            'desconto': TextEditingController(
              text: (value['desconto'] ?? 0.0).toString(),
            ),
          };
        });
      }

      if (dados['faixas_volume'] != null) {
        List faixasVol = dados['faixas_volume'];
        for (var f in faixasVol) {
          _faixasVolume.add({
            'valorInicial': TextEditingController(
              text: (f['valor_inicial'] ?? 0.0).toString(),
            ),
            'valorFinal': TextEditingController(
              text: (f['valor_final'] ?? 0.0).toString(),
            ),
            'modComissao': TextEditingController(
              text: (f['modificador_comissao'] ?? 0.0).toString(),
            ),
            'modDesconto': TextEditingController(
              text: (f['modificador_desconto'] ?? 0.0).toString(),
            ),
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descontoMaximoController.dispose();
    _comissaoFixaController.dispose();
    for (var faixa in _faixasComissao) {
      faixa['descInicial']?.dispose();
      faixa['descFinal']?.dispose();
      faixa['comissao']?.dispose();
    }
    _modificadoresPagamento.forEach((key, controllers) {
      controllers['comissao']?.dispose();
      controllers['desconto']?.dispose();
    });
    for (var faixaVol in _faixasVolume) {
      faixaVol['valorInicial']?.dispose();
      faixaVol['valorFinal']?.dispose();
      faixaVol['modComissao']?.dispose();
      faixaVol['modDesconto']?.dispose();
    }
    super.dispose();
  }

  void _adicionarFaixaComissao() {
    setState(() {
      _faixasComissao.add({
        'descInicial': TextEditingController(),
        'descFinal': TextEditingController(),
        'comissao': TextEditingController(),
      });
    });
  }

  void _removerFaixaComissao(int index) {
    setState(() {
      _faixasComissao[index]['descInicial']?.dispose();
      _faixasComissao[index]['descFinal']?.dispose();
      _faixasComissao[index]['comissao']?.dispose();
      _faixasComissao.removeAt(index);
    });
  }

  void _adicionarFaixaVolume() {
    setState(() {
      _faixasVolume.add({
        'valorInicial': TextEditingController(),
        'valorFinal': TextEditingController(),
        'modComissao': TextEditingController(),
        'modDesconto': TextEditingController(),
      });
    });
  }

  void _removerFaixaVolume(int index) {
    setState(() {
      _faixasVolume[index]['valorInicial']?.dispose();
      _faixasVolume[index]['valorFinal']?.dispose();
      _faixasVolume[index]['modComissao']?.dispose();
      _faixasVolume[index]['modDesconto']?.dispose();
      _faixasVolume.removeAt(index);
    });
  }

  Future<void> _salvarPoliticaNoBanco() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoComissao == 'Escalonada' && _faixasComissao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione pelo menos uma faixa de comissão escalonada.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      List<Map<String, double>> faixasParaSalvar = [];
      if (_tipoComissao == 'Escalonada') {
        for (var faixa in _faixasComissao) {
          faixasParaSalvar.add({
            'desconto_inicial':
                double.tryParse(
                  faixa['descInicial']!.text.replaceAll(',', '.'),
                ) ??
                0.0,
            'desconto_final':
                double.tryParse(
                  faixa['descFinal']!.text.replaceAll(',', '.'),
                ) ??
                0.0,
            'percentual_comissao':
                double.tryParse(faixa['comissao']!.text.replaceAll(',', '.')) ??
                0.0,
          });
        }
      }

      Map<String, Map<String, double>> modificadoresParaSalvar = {};
      _modificadoresPagamento.forEach((id, ctrls) {
        double modComissao =
            double.tryParse(ctrls['comissao']!.text.replaceAll(',', '.')) ??
            0.0;
        double modDesconto =
            double.tryParse(ctrls['desconto']!.text.replaceAll(',', '.')) ??
            0.0;
        if (modComissao != 0.0 || modDesconto != 0.0) {
          modificadoresParaSalvar[id] = {
            'comissao': modComissao,
            'desconto': modDesconto,
          };
        }
      });

      List<Map<String, double>> faixasVolumeSalvar = [];
      for (var faixaVol in _faixasVolume) {
        faixasVolumeSalvar.add({
          'valor_inicial':
              double.tryParse(
                faixaVol['valorInicial']!.text.replaceAll(',', '.'),
              ) ??
              0.0,
          'valor_final':
              double.tryParse(
                faixaVol['valorFinal']!.text.replaceAll(',', '.'),
              ) ??
              0.0,
          'modificador_comissao':
              double.tryParse(
                faixaVol['modComissao']!.text.replaceAll(',', '.'),
              ) ??
              0.0,
          'modificador_desconto':
              double.tryParse(
                faixaVol['modDesconto']!.text.replaceAll(',', '.'),
              ) ??
              0.0,
        });
      }

      final payloadPolitica = {
        'empresa_id': widget.empresaId,
        'nome_politica': _nomeController.text.trim().toUpperCase(),
        'ativo': _ativo,
        'desconto_maximo_permitido':
            double.tryParse(
              _descontoMaximoController.text.replaceAll(',', '.'),
            ) ??
            0.0,
        'acao_extrapolacao': _acaoAoUltrapassarDesconto,
        'tipo_comissao': _tipoComissao,
        'comissao_fixa': _tipoComissao == 'Fixa'
            ? (double.tryParse(
                    _comissaoFixaController.text.replaceAll(',', '.'),
                  ) ??
                  0.0)
            : null,
        'faixas_escalonadas': _tipoComissao == 'Escalonada'
            ? faixasParaSalvar
            : null,
        'modificadores_pagamento': modificadoresParaSalvar,
        'faixas_volume': faixasVolumeSalvar,
        'data_atualizacao': FieldValue.serverTimestamp(),
      };

      if (widget.politicaId == null) {
        payloadPolitica['data_criacao'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('politicas_comerciais')
            .add(payloadPolitica);
      } else {
        await FirebaseFirestore.instance
            .collection('politicas_comerciais')
            .doc(widget.politicaId)
            .update(payloadPolitica);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.politicaId == null
                  ? 'Política criada com sucesso!'
                  : 'Política atualizada!',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar no banco: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEdicao = widget.politicaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdicao ? 'Editar Política Comercial' : 'Nova Política Comercial',
        ),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // BLOCO 1: IDENTIFICAÇÃO
              // ==========================================
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Identificação da Regra',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                          Switch(
                            value: _ativo,
                            activeColor: Colors.teal,
                            onChanged: (val) => setState(() => _ativo = val),
                          ),
                        ],
                      ),
                      const Divider(),
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText:
                              'Nome do Pacote Comercial (Ex: VENDEDOR SÊNIOR)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // BLOCO 2: LIMITES DE DESCONTO
              // ==========================================
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limites e Autonomia de Desconto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.indigo,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _descontoMaximoController,
                              decoration: const InputDecoration(
                                labelText: 'Teto Máx. (%)',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.percent, size: 16),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _acaoAoUltrapassarDesconto,
                              decoration: const InputDecoration(
                                labelText: 'Se o vendedor ultrapassar o teto:',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Bloquear Venda',
                                  child: Text('Bloquear Venda (Não Salva)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Enviar Diretoria',
                                  child: Text('Salvar e Enviar p/ Diretoria'),
                                ),
                                DropdownMenuItem(
                                  value: 'Passe Livre',
                                  child: Text('Permitir (Passe Livre)'),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _acaoAoUltrapassarDesconto = v!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // BLOCO 3: MATEMÁTICA DE COMISSIONAMENTO
              // ==========================================
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Matemática de Comissionamento',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                'Comissão Fixa',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: 'Fixa',
                              groupValue: _tipoComissao,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setState(() => _tipoComissao = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                'Escalonada (Por Desconto)',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: 'Escalonada',
                              groupValue: _tipoComissao,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setState(() => _tipoComissao = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_tipoComissao == 'Fixa')
                        TextFormField(
                          controller: _comissaoFixaController,
                          decoration: const InputDecoration(
                            labelText: 'Percentual Fixo de Comissão (%)',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.percent, size: 16),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.amber.shade50,
                              child: const Text(
                                'Crie as faixas: Ex: Se o desconto for de 0% a 5%, a comissão é 10%.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._faixasComissao.asMap().entries.map((entry) {
                              int idx = entry.key;
                              var ctrls = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['descInicial'],
                                        decoration: const InputDecoration(
                                          labelText: 'Desc. De (%)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text('até'),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['descFinal'],
                                        decoration: const InputDecoration(
                                          labelText: 'Desc. Até (%)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['comissao'],
                                        decoration: const InputDecoration(
                                          labelText: 'Comissão (%)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _removerFaixaComissao(idx),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            TextButton.icon(
                              onPressed: _adicionarFaixaComissao,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar Faixa de Comissão'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // BLOCO 4: MODIFICADORES POR PRAZO DE PAGAMENTO
              // ==========================================
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modificadores por Prazo de Pagamento',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Utilize valores (+) para beneficiar prazos curtos ou (-) para penalizar prazos longos.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      const Divider(),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('condicoes_pagamento')
                            .where('empresa_id', isEqualTo: widget.empresaId)
                            .where('ativo', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          // Filtra as condições que ainda NÃO foram adicionadas à lista
                          var condicoesDisponiveis = docs
                              .where(
                                (d) =>
                                    !_modificadoresPagamento.containsKey(d.id),
                              )
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. LINHA DE ADIÇÃO COM LISTA SUSPENSA (DROPDOWN)
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _condicaoPagamentoSelecionada,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Selecione a Condição de Pagamento',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: condicoesDisponiveis.map((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        // CORREÇÃO APLICADA: Lendo do campo 'nome'
                                        return DropdownMenuItem<String>(
                                          value: doc.id,
                                          child: Text(
                                            data['nome'] ?? 'Sem Nome',
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(
                                        () =>
                                            _condicaoPagamentoSelecionada = val,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text(
                                      'Adicionar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      if (_condicaoPagamentoSelecionada !=
                                          null) {
                                        setState(() {
                                          _modificadoresPagamento[_condicaoPagamentoSelecionada!] =
                                              {
                                                'comissao':
                                                    TextEditingController(
                                                      text: '0.0',
                                                    ),
                                                'desconto':
                                                    TextEditingController(
                                                      text: '0.0',
                                                    ),
                                              };
                                          _condicaoPagamentoSelecionada =
                                              null; // Limpa para a próxima
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2. LISTA DAS CONDIÇÕES ADICIONADAS
                              if (_modificadoresPagamento.isEmpty)
                                const Text(
                                  'Nenhuma regra específica de prazo adicionada.',
                                  style: TextStyle(color: Colors.grey),
                                ),

                              ..._modificadoresPagamento.keys.map((idCondicao) {
                                var ctrls =
                                    _modificadoresPagamento[idCondicao]!;

                                // Busca o nome correto na lista do banco
                                String nomeExibicao =
                                    'Condição Excluída/Inativa';
                                try {
                                  var docRelacionado = docs.firstWhere(
                                    (d) => d.id == idCondicao,
                                  );
                                  nomeExibicao =
                                      (docRelacionado.data()
                                          as Map<String, dynamic>)['nome'] ??
                                      'Sem Nome';
                                } catch (e) {
                                  // Se a condição foi apagada do banco, mantém o alerta
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          nomeExibicao,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller: ctrls['desconto'],
                                          decoration: const InputDecoration(
                                            labelText: 'Teto Desc.(%)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                signed: true,
                                                decimal: true,
                                              ),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller: ctrls['comissao'],
                                          decoration: const InputDecoration(
                                            labelText: 'Comissão (%)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                signed: true,
                                                decimal: true,
                                              ),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _modificadoresPagamento[idCondicao]?['comissao']
                                                ?.dispose();
                                            _modificadoresPagamento[idCondicao]?['desconto']
                                                ?.dispose();
                                            _modificadoresPagamento.remove(
                                              idCondicao,
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // BLOCO 5: MODIFICADORES POR VOLUME (TICKET MÉDIO)
              // ==========================================
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aceleradores de Upsell (Bônus por Volume)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Incentive o aumento do Ticket Médio dando bônus (+) caso o Total do Pedido atinja certas metas.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      const Divider(),

                      ..._faixasVolume.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var ctrls = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['valorInicial'],
                                        decoration: const InputDecoration(
                                          labelText: 'De (R\$)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          prefixText: 'R\$ ',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text('até'),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['valorFinal'],
                                        decoration: const InputDecoration(
                                          labelText: 'Até (R\$)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          prefixText: 'R\$ ',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removerFaixaVolume(idx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['modDesconto'],
                                        decoration: const InputDecoration(
                                          labelText: 'Bônus Limite Desc. (%)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              signed: true,
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrls['modComissao'],
                                        decoration: const InputDecoration(
                                          labelText: 'Bônus Comissão (%)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              signed: true,
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      TextButton.icon(
                        onPressed: _adicionarFaixaVolume,
                        icon: const Icon(Icons.add, color: Colors.orange),
                        label: const Text(
                          'Adicionar Meta de Volume',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _salvando ? null : _salvarPoliticaNoBanco,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isEdicao ? 'ATUALIZAR POLÍTICA' : 'SALVAR NOVA POLÍTICA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
