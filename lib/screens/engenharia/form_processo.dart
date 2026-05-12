import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormProcesso extends StatefulWidget {
  final DocumentSnapshot? documento;

  const FormProcesso({super.key, this.documento});

  @override
  State<FormProcesso> createState() => _FormProcessoState();
}

class _FormProcessoState extends State<FormProcesso> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _custoController = TextEditingController();

  String _execucao = 'Interna';
  String _baseCusto = 'Por Peça';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    if (widget.documento != null) {
      final data = widget.documento!.data() as Map<String, dynamic>;
      _nomeController.text = data['nome'] ?? '';
      _custoController.text = (data['custoPadrao'] ?? 0.0)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _execucao = data['execucao'] ?? 'Interna';
      _baseCusto = data['baseCusto'] ?? 'Por Peça';
    }
  }

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);
      try {
        double custoPadrao =
            double.tryParse(
              _custoController.text.replaceAll('.', '').replaceAll(',', '.'),
            ) ??
            0.0;

        final dados = {
          'clienteId': 'teste_textil',
          'nome': _nomeController.text.trim(),
          'execucao': _execucao,
          'baseCusto': _baseCusto,
          'custoPadrao': custoPadrao,
          'dataUltimaAtualizacao':
              FieldValue.serverTimestamp(), // GRAVA A DATA ATUAL
          if (widget.documento == null) 'ativo': true,
        };

        if (widget.documento == null) {
          await FirebaseFirestore.instance
              .collection('engenharia_processos')
              .add(dados);
        } else {
          await FirebaseFirestore.instance
              .collection('engenharia_processos')
              .doc(widget.documento!.id)
              .update(dados);
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documento != null ? 'Editar Processo' : 'Novo Processo',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Processo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Execução:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Interna'),
                      value: 'Interna',
                      groupValue: _execucao,
                      onChanged: (v) => setState(() => _execucao = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Externa'),
                      value: 'Externa',
                      groupValue: _execucao,
                      onChanged: (v) => setState(() => _execucao = v!),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Base',
                        border: OutlineInputBorder(),
                      ),
                      value: _baseCusto,
                      items: ['Por Peça', 'Por Kg', 'Por Hora', 'Por Metro']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _baseCusto = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _custoController,
                      decoration: const InputDecoration(
                        labelText: 'Custo R\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SALVAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
