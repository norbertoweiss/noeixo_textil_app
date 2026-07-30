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
  late bool _isAtivo;

  // =========================================================================
  // CONTROLADORES
  // =========================================================================
  late final TextEditingController _razaoCtrl;
  late final TextEditingController _fantasiaCtrl;
  late final TextEditingController _cnpjCtrl;
  late final TextEditingController _ieCtrl;
  late final TextEditingController _cepCtrl;
  late final TextEditingController _ruaCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _bairroCtrl;
  late final TextEditingController _cidadeCtrl;
  late final TextEditingController _ufCtrl;
  late final TextEditingController _grupoCtrl;
  late final TextEditingController _compradorCtrl;
  late final TextEditingController _whatsCtrl;
  late final TextEditingController _telefoneFixoCtrl; // NOVO CAMPO
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final dados = widget.dadosIniciais;

    _isAtivo = dados['ativo'] ?? true;

    // =========================================================================
    // MAPEAMENTO EXATO CONFORME ESTRUTURA OFICIAL DO FIREBASE
    // =========================================================================
    _razaoCtrl = TextEditingController(text: dados['razao_social'] ?? '');
    _fantasiaCtrl = TextEditingController(text: dados['nome_fantasia'] ?? '');
    _cnpjCtrl = TextEditingController(text: dados['cnpj'] ?? '');
    _ieCtrl = TextEditingController(text: dados['ie'] ?? '');
    _cepCtrl = TextEditingController(text: (dados['cep'] ?? '').toString());
    _ruaCtrl = TextEditingController(text: dados['logradouro'] ?? '');
    _numCtrl = TextEditingController(text: (dados['numero'] ?? '').toString());
    _bairroCtrl = TextEditingController(text: dados['bairro'] ?? '');
    _cidadeCtrl = TextEditingController(text: dados['cidade'] ?? '');
    _ufCtrl = TextEditingController(text: dados['estado'] ?? '');
    _grupoCtrl = TextEditingController(text: dados['grupo_economico'] ?? '');
    _compradorCtrl = TextEditingController(
      text: dados['contato_comprador'] ?? '',
    );

    _whatsCtrl = TextEditingController(text: dados['whatsapp'] ?? '');
    _telefoneFixoCtrl = TextEditingController(
      text: dados['telefone_fixo'] ?? '',
    ); // LENDO O FIXO
    _emailCtrl = TextEditingController(text: dados['email'] ?? '');
  }

  @override
  void dispose() {
    _razaoCtrl.dispose();
    _fantasiaCtrl.dispose();
    _cnpjCtrl.dispose();
    _ieCtrl.dispose();
    _cepCtrl.dispose();
    _ruaCtrl.dispose();
    _numCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _grupoCtrl.dispose();
    _compradorCtrl.dispose();
    _whatsCtrl.dispose();
    _telefoneFixoCtrl.dispose(); // LIMPANDO O FIXO DA MEMÓRIA
    _emailCtrl.dispose();
    super.dispose();
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
            'ie': _ieCtrl.text,
            'cep': _cepCtrl.text,
            'logradouro': _ruaCtrl.text,
            'numero': _numCtrl.text,
            'bairro': _bairroCtrl.text,
            'cidade': _cidadeCtrl.text.toUpperCase().trim(),
            'estado': _ufCtrl.text.toUpperCase().trim(),
            'grupo_economico': _grupoCtrl.text,
            'contato_comprador': _compradorCtrl.text,
            'whatsapp': _whatsCtrl.text,
            'telefone_fixo': _telefoneFixoCtrl.text, // SALVANDO NO BD
            'email': _emailCtrl.text,
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

                    // =========================================================
                    // WHATSAPP E TELEFONE FIXO LADO A LADO
                    // =========================================================
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
                          child: TextFormField(
                            controller: _telefoneFixoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Telefone Fixo',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // =========================================================
                    // E-MAIL OCUPANDO A LINHA INTEIRA PARA NÃO CORTAR TEXTO
                    // =========================================================
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
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
