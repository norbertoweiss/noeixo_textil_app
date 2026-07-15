import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// INJEÇÃO DO GATILHO: MOTOR DE ROTEAMENTO
// ============================================================================
import '../smart/motor_roteamento.dart';

class FormFichaCliente extends StatefulWidget {
  final String empresaId;
  final String? clienteId;
  final Map<String, dynamic>? dadosIniciais;

  const FormFichaCliente({
    super.key,
    required this.empresaId,
    this.clienteId,
    this.dadosIniciais,
  });

  @override
  State<FormFichaCliente> createState() => _FormFichaClienteState();
}

class _FormFichaClienteState extends State<FormFichaCliente> {
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  bool _ativo = true;
  String? _motivoInativacao;

  late TextEditingController _cnpjController;
  late TextEditingController _ieController;
  late TextEditingController _razaoController;
  late TextEditingController _fantasiaController;

  late TextEditingController _compradorController;
  late TextEditingController _whatsappController;
  late TextEditingController _telefoneFixoController;
  late TextEditingController _emailController;

  late TextEditingController _cepController;
  late TextEditingController _logradouroController;
  late TextEditingController _numeroController;
  late TextEditingController _complementoController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _estadoController;

  @override
  void initState() {
    super.initState();
    final d = widget.dadosIniciais ?? {};

    _ativo = d['ativo'] ?? true;
    _motivoInativacao = d['motivo_inativacao'];

    // =========================================================================
    // PADRONIZAÇÃO ABSOLUTA COM A MÁQUINA DE IMPORTAÇÃO CSV
    // =========================================================================
    _cnpjController = TextEditingController(text: d['cnpj'] ?? '');
    _ieController = TextEditingController(text: d['ie'] ?? '');
    _razaoController = TextEditingController(text: d['razao_social'] ?? '');
    _fantasiaController = TextEditingController(text: d['nome_fantasia'] ?? '');
    _compradorController = TextEditingController(
      text: d['contato_comprador'] ?? '',
    );
    _whatsappController = TextEditingController(text: d['whatsapp'] ?? '');
    _telefoneFixoController = TextEditingController(
      text: d['telefone_fixo'] ?? '',
    );
    _emailController = TextEditingController(text: d['email'] ?? '');
    _cepController = TextEditingController(text: d['cep'] ?? '');
    _logradouroController = TextEditingController(text: d['logradouro'] ?? '');
    _numeroController = TextEditingController(text: d['numero'] ?? '');
    _complementoController = TextEditingController(
      text: d['complemento'] ?? '',
    );
    _bairroController = TextEditingController(text: d['bairro'] ?? '');
    _cidadeController = TextEditingController(text: d['cidade'] ?? '');
    _estadoController = TextEditingController(text: d['estado'] ?? '');
  }

  @override
  void dispose() {
    _cnpjController.dispose();
    _ieController.dispose();
    _razaoController.dispose();
    _fantasiaController.dispose();
    _compradorController.dispose();
    _whatsappController.dispose();
    _telefoneFixoController.dispose();
    _emailController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  List<String> _verificarCamposPendentes() {
    List<String> pendencias = [];
    if (_ieController.text.trim().isEmpty) pendencias.add('Inscrição Estadual');
    if (_cepController.text.trim().isEmpty) pendencias.add('CEP');
    if (_numeroController.text.trim().isEmpty) pendencias.add('Número');
    if (_emailController.text.trim().isEmpty) pendencias.add('E-mail');
    if (_bairroController.text.trim().isEmpty) pendencias.add('Bairro');
    return pendencias;
  }

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      String cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
      String docId = widget.clienteId ?? '${widget.empresaId}_$cnpjLimpo';

      Map<String, dynamic> dadosParaSalvar = {
        'empresa_id': widget.empresaId,
        'ativo': _ativo,
        'motivo_inativacao': _ativo ? null : _motivoInativacao,
        'cnpj': cnpjLimpo,
        'ie': _ieController.text.trim(),
        'razao_social': _razaoController.text.trim(),
        'nome_fantasia': _fantasiaController.text.trim(),
        'contato_comprador': _compradorController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'telefone_fixo': _telefoneFixoController.text.trim(),
        'email': _emailController.text.trim(),
        'cep': _cepController.text.trim(),
        'logradouro': _logradouroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'estado': _estadoController.text.trim(),
        'atualizado_em': FieldValue.serverTimestamp(),
      };

      if (widget.clienteId == null) {
        dadosParaSalvar['representante_id'] = 'Lista Clientes Importada';
        dadosParaSalvar['status_credito'] = 'Pendente Enriquecimento';
        dadosParaSalvar['data_importacao'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(docId)
          .set(dadosParaSalvar, SetOptions(merge: true));

      // =======================================================================
      // INJEÇÃO DO GATILHO AQUI: Roda após o salvamento manual
      // =======================================================================
      await MotorRoteamento.sincronizarGeral();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ficha do cliente salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _adicionarMotivoInline() {
    TextEditingController novoMotivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Motivo de Inativação'),
        content: TextField(
          controller: novoMotivoCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ex: MUDOU DE RAMO',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (novoMotivoCtrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('parametros_gestao')
                    .add({
                      'empresa_id': widget.empresaId,
                      'tipo': 'MOTIVOS DE INATIVAÇÃO',
                      'descricao': novoMotivoCtrl.text.trim().toUpperCase(),
                      'criado_em': FieldValue.serverTimestamp(),
                    });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Salvar e Usar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalInativacao() {
    String? motivoSelecionado;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Inativar Cliente',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por favor, informe a razão para inativar este cliente.',
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('parametros_gestao')
                        .where('empresa_id', isEqualTo: widget.empresaId)
                        .where('tipo', isEqualTo: 'MOTIVOS DE INATIVAÇÃO')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      var docs = snapshot.data!.docs;
                      List<String> motivos = docs
                          .map(
                            (d) =>
                                (d.data() as Map<String, dynamic>)['descricao']
                                    .toString(),
                          )
                          .toList();
                      motivos.sort();

                      if (motivoSelecionado != null &&
                          !motivos.contains(motivoSelecionado)) {
                        motivoSelecionado = null;
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Selecione o Motivo...'),
                              value: motivoSelecionado,
                              items: motivos
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setStateModal(() => motivoSelecionado = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Criar Novo Motivo',
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.blueGrey,
                                size: 36,
                              ),
                              onPressed: _adicionarMotivoInline,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: motivoSelecionado == null
                      ? null
                      : () {
                          setState(() {
                            _ativo = false;
                            _motivoInativacao = motivoSelecionado;
                          });
                          Navigator.pop(context);
                          _salvarCliente();
                        },
                  child: const Text('Confirmar Inativação'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEdicao = widget.clienteId != null;
    List<String> camposFaltando = _verificarCamposPendentes();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Ficha do Cliente' : 'Novo Prospecto'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (isEdicao && camposFaltando.isNotEmpty && _ativo)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ficha em enriquecimento. Para emissão futura de NFe, considere preencher: ${camposFaltando.join(", ")}.',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            _construirCabecalhoBloco('Identificação Principal', Icons.badge),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cnpjController,
                    decoration: const InputDecoration(
                      labelText: 'CNPJ *',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: isEdicao,
                    style: TextStyle(
                      color: isEdicao ? Colors.grey.shade700 : Colors.black,
                    ),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ieController,
                    decoration: const InputDecoration(
                      labelText: 'Inscrição Estadual (IE)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _razaoController,
                    decoration: const InputDecoration(
                      labelText: 'Razão Social',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fantasiaController,
              decoration: const InputDecoration(
                labelText: 'Nome Fantasia',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            _construirCabecalhoBloco(
              'Comunicação e Contatos',
              Icons.headset_mic,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _compradorController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Comprador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail (NFe)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp / Celular',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _telefoneFixoController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone Fixo (Empresa)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            _construirCabecalhoBloco('Endereço Fiscal', Icons.location_on),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _cepController,
                    decoration: const InputDecoration(
                      labelText: 'CEP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _logradouroController,
                    decoration: const InputDecoration(
                      labelText: 'Logradouro / Rua',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _complementoController,
                    decoration: const InputDecoration(
                      labelText: 'Complemento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _bairroController,
                    decoration: const InputDecoration(
                      labelText: 'Bairro',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cidadeController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _estadoController,
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                if (isEdicao && _ativo)
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _abrirModalInativacao,
                        icon: const Icon(Icons.block),
                        label: const Text(
                          'INATIVAR CLIENTE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ),

                if (isEdicao && !_ativo)
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _ativo = true;
                            _motivoInativacao = null;
                          });
                          _salvarCliente();
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text(
                          'REATIVAR CLIENTE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                  ),

                if (isEdicao) const SizedBox(width: 16),

                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvarCliente,
                      icon: _salvando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.save),
                      label: const Text(
                        'SALVAR FICHA DO CLIENTE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _construirCabecalhoBloco(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icone, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}
