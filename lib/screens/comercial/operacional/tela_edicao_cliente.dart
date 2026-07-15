import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaEdicaoClienteCompleta extends StatefulWidget {
  final String clienteId;
  final Map<String, dynamic> dadosIniciais;

  const TelaEdicaoClienteCompleta({
    super.key,
    required this.clienteId,
    required this.dadosIniciais,
  });

  @override
  State<TelaEdicaoClienteCompleta> createState() =>
      _TelaEdicaoClienteCompletaState();
}

class _TelaEdicaoClienteCompletaState extends State<TelaEdicaoClienteCompleta> {
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  bool _isAtivo = true;

  final _razaoCtrl = TextEditingController();
  final _fantasiaCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _ieCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _ruaCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _grupoCtrl = TextEditingController();
  final _compradorCtrl = TextEditingController();
  final _whatsCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isAtivo = widget.dadosIniciais['ativo'] ?? true;
    _razaoCtrl.text = widget.dadosIniciais['razao_social'] ?? '';
    _fantasiaCtrl.text = widget.dadosIniciais['nome_fantasia'] ?? '';
    _cnpjCtrl.text = widget.dadosIniciais['cnpj'] ?? '';
    _ieCtrl.text = widget.dadosIniciais['inscricao_estadual'] ?? '';
    _cepCtrl.text = widget.dadosIniciais['cep_fiscal'] ?? '';
    _ruaCtrl.text = widget.dadosIniciais['rua_fiscal'] ?? '';
    _numCtrl.text = widget.dadosIniciais['num_fiscal'] ?? '';
    _bairroCtrl.text = widget.dadosIniciais['bairro_fiscal'] ?? '';
    _cidadeCtrl.text = widget.dadosIniciais['cidade_fiscal'] ?? '';
    _ufCtrl.text = widget.dadosIniciais['uf_fiscal'] ?? '';
    _grupoCtrl.text = widget.dadosIniciais['grupo_economico'] ?? '';
    _compradorCtrl.text = widget.dadosIniciais['contato_comprador'] ?? '';
    _whatsCtrl.text = widget.dadosIniciais['whatsapp'] ?? '';
    _emailCtrl.text = widget.dadosIniciais['email_nfe'] ?? '';
  }

  Future<void> _salvarEdicaoCompleta() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(widget.clienteId)
          .update({
            'ativo': _isAtivo,
            'razao_social': _razaoCtrl.text.toUpperCase(),
            'nome_fantasia': _fantasiaCtrl.text.toUpperCase(),
            'inscricao_estadual': _ieCtrl.text,
            'cep_fiscal': _cepCtrl.text,
            'rua_fiscal': _ruaCtrl.text,
            'num_fiscal': _numCtrl.text,
            'bairro_fiscal': _bairroCtrl.text,
            'cidade_fiscal': _cidadeCtrl.text,
            'uf_fiscal': _ufCtrl.text,
            'grupo_economico': _grupoCtrl.text,
            'contato_comprador': _compradorCtrl.text,
            'whatsapp': _whatsCtrl.text,
            'email_nfe': _emailCtrl.text,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ficha atualizada com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edição de Ficha Cadastral'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _salvando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: _isAtivo
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      margin: const EdgeInsets.only(bottom: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _isAtivo
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          _isAtivo
                              ? '🟢 CLIENTE ATIVO NO SISTEMA'
                              : '🔴 CLIENTE INATIVO (BLOQUEADO)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isAtivo
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                        subtitle: const Text(
                          'Desligue para ocultar este cliente da rota diária e bloquear novos pedidos.',
                        ),
                        value: _isAtivo,
                        activeColor: Colors.green,
                        onChanged: (val) => setState(() => _isAtivo = val),
                      ),
                    ),
                    const Text(
                      'Identificação Principal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _cnpjCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ (Bloqueado para Edição)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.black12,
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _razaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Razão Social',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fantasiaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome Fantasia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ieCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Inscrição Estadual',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Dados de Contato',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _compradorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Comprador',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _whatsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _grupoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Grupo Econômico / Rede',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Endereço Fiscal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cepCtrl,
                            decoration: const InputDecoration(
                              labelText: 'CEP',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cidadeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _ufCtrl,
                            decoration: const InputDecoration(
                              labelText: 'UF',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _ruaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Logradouro / Rua',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _numCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Número',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bairroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'SALVAR ALTERAÇÕES CADASTRAIS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _salvarEdicaoCompleta,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
