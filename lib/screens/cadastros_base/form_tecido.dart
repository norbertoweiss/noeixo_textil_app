import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormTecido extends StatefulWidget {
  const FormTecido({super.key});

  @override
  State<FormTecido> createState() => _FormTecidoState();
}

class _FormTecidoState extends State<FormTecido> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _composicaoController = TextEditingController();
  final TextEditingController _gramaturaController = TextEditingController();
  final TextEditingController _rendimentoController = TextEditingController();
  final TextEditingController _larguraController = TextEditingController();
  final TextEditingController _custoController = TextEditingController();

  String _tipoProcesso = 'Compra de Malha Tingida (Pronta)';
  final List<String> _opcoesProcesso = [
    'Compra de Fio (Para Tecer e Tingir)',
    'Compra de Malha Crua (Para Tingir)',
    'Compra de Malha Tingida (Pronta)',
  ];

  bool _salvando = false;

  // A MÁGICA DA FÍSICA TÊXTIL (Agora com setState para forçar a tela a piscar)
  void _calcularRendimento() {
    double? gramatura = double.tryParse(
      _gramaturaController.text.replaceAll(',', '.'),
    );
    double? largura = double.tryParse(
      _larguraController.text.replaceAll(',', '.'),
    );

    if (gramatura != null && largura != null && gramatura > 0 && largura > 0) {
      double rendimento = 1000 / (gramatura * largura);
      setState(() {
        _rendimentoController.text = rendimento.toStringAsFixed(3);
      });
    } else {
      setState(() {
        _rendimentoController.text = ''; // Limpa se apagar os valores
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Tecido / Malha'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Tecido (ex: Meia Malha Penteada 30/1)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.texture),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _composicaoController,
                  decoration: const InputDecoration(
                    labelText: 'Composição (ex: 100% Algodão)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: _tipoProcesso,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Aquisição / Processo Inicial',
                    border: OutlineInputBorder(),
                  ),
                  items: _opcoesProcesso.map((String opcao) {
                    return DropdownMenuItem<String>(
                      value: opcao,
                      child: Text(opcao),
                    );
                  }).toList(),
                  onChanged: (String? novoValor) {
                    setState(() {
                      if (novoValor != null) _tipoProcesso = novoValor;
                    });
                  },
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _gramaturaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Gramatura (g/m²)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            _calcularRendimento(), // GATILHO ADICIONADO AQUI
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _larguraController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Largura (metros)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            _calcularRendimento(), // GATILHO ADICIONADO AQUI
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rendimentoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Rendimento (m/kg)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.amberAccent.withOpacity(0.1),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _custoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Custo Referência R\$/Kg',
                          border: OutlineInputBorder(),
                          prefixText: 'R\$ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '* O Custo Referência é apenas para a Ficha Técnica Base. O custo real será calculado dinamicamente pelas ordens de compra/beneficiamento.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _salvando
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _salvando = true;
                              });

                              try {
                                final db = FirebaseFirestore.instance;
                                String idFinal = db
                                    .collection('tecidos')
                                    .doc()
                                    .id;

                                double rendimentoVal =
                                    double.tryParse(
                                      _rendimentoController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0.0;
                                double larguraVal =
                                    double.tryParse(
                                      _larguraController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0.0;
                                double gramaturaVal =
                                    double.tryParse(
                                      _gramaturaController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0.0;
                                double custoVal =
                                    double.tryParse(
                                      _custoController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0.0;

                                await db
                                    .collection('tecidos')
                                    .doc(idFinal)
                                    .set({
                                      'id': idFinal,
                                      'clienteId': 'teste_textil',
                                      'nome': _nomeController.text,
                                      'composicao': _composicaoController.text,
                                      'tipoProcesso': _tipoProcesso,
                                      'gramatura': gramaturaVal,
                                      'rendimento': rendimentoVal,
                                      'largura': larguraVal,
                                      'custoBase': custoVal,
                                      'ativo': true,
                                    });

                                if (mounted) {
                                  Navigator.pop(context, true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tecido salvo na nuvem com sucesso!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('ERRO AO SALVAR: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _salvando = false;
                                  });
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                    child: _salvando
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'GUARDAR TECIDO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
