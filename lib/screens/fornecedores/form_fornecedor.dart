import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'form_categoria_fornecedor.dart';

class FormFornecedor extends StatefulWidget {
  final DocumentSnapshot? fornecedorParaEditar;
  const FormFornecedor({super.key, this.fornecedorParaEditar});

  @override
  State<FormFornecedor> createState() => _FormFornecedorState();
}

class _FormFornecedorState extends State<FormFornecedor> {
  final _formKey = GlobalKey<FormState>();

  final _razaoSocialController = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  final _documentoController = TextEditingController();
  final _ieController = TextEditingController();

  // --- NOVOS CONTROLADORES DE CONTATO ---
  final _telefoneEmpresaController =
      TextEditingController(); // Antigo _telefoneController
  final _telefoneVendedorController = TextEditingController(); // NOVO
  final _emailController = TextEditingController();

  final _siteController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();

  final _obsController = TextEditingController();

  String? _classeSelecionadaNome;
  String? _subclasseSelecionada;
  List<DocumentSnapshot> _listaClasses = [];
  List<String> _subclassesDisponiveis = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarClassesIniciais();
    if (widget.fornecedorParaEditar != null) {
      _preencherDadosEdicao();
    }
  }

  Future<void> _carregarClassesIniciais() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('categorias_fornecedor')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();

    setState(() {
      _listaClasses = snapshot.docs;
      if (_classeSelecionadaNome != null &&
          _listaClasses.any((d) => d['nome'] == _classeSelecionadaNome)) {
        _atualizarListaSubclasses(_classeSelecionadaNome!);
      }
    });
  }

  void _atualizarListaSubclasses(String nomeClasse) {
    var doc = _listaClasses.firstWhere((d) => d['nome'] == nomeClasse);
    List subList = doc['subgrupos'] ?? [];
    setState(() {
      _subclassesDisponiveis = subList.map((e) {
        if (e is Map) return e['nome'].toString();
        return e.toString();
      }).toList();
      _subclassesDisponiveis.sort((a, b) => a.compareTo(b));
    });
  }

  void _preencherDadosEdicao() {
    final d = widget.fornecedorParaEditar!.data() as Map<String, dynamic>;
    _razaoSocialController.text = d['nome'] ?? '';
    _nomeFantasiaController.text = d['nomeFantasia'] ?? '';
    _documentoController.text = d['documento'] ?? '';
    _ieController.text = d['ie'] ?? '';
    _telefoneEmpresaController.text =
        d['contato'] ?? ''; // Puxa do antigo para manter compatibilidade
    _telefoneVendedorController.text =
        d['whatsappVendedor'] ?? ''; // Puxa o novo
    _emailController.text = d['email'] ?? '';
    _siteController.text = d['site'] ?? '';
    _cepController.text = d['cep'] ?? '';
    _enderecoController.text = d['endereco'] ?? '';
    _numeroController.text = d['numero'] ?? '';
    _bairroController.text = d['bairro'] ?? '';
    _cidadeController.text = d['cidade'] ?? '';
    _estadoController.text = d['estado'] ?? '';
    _obsController.text = d['observacoes'] ?? '';
    _classeSelecionadaNome = d['grupoNome'];
    _subclasseSelecionada = d['subcategoria'];
  }

  Future<void> _atalhoNovaClasse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FormCategoriaFornecedor()),
    );
    await _carregarClassesIniciais();
  }

  Future<void> _atalhoNovaSubclasseRapida() async {
    if (_classeSelecionadaNome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma Classe primeiro.'),
        ),
      );
      return;
    }

    TextEditingController novaSubController = TextEditingController();
    String? novaSub = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nova Subclasse em "$_classeSelecionadaNome"'),
        content: TextField(
          controller: novaSubController,
          decoration: const InputDecoration(
            hintText: 'Ex: Produtos Químicos',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, novaSubController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novaSub != null && novaSub.isNotEmpty) {
      setState(() => _carregando = true);
      try {
        var docClasse = _listaClasses.firstWhere(
          (d) => d['nome'] == _classeSelecionadaNome,
        );
        List subList = docClasse['subgrupos'] ?? [];

        bool jaExiste = subList.any((e) {
          if (e is Map)
            return e['nome'].toString().toLowerCase() == novaSub.toLowerCase();
          return e.toString().toLowerCase() == novaSub.toLowerCase();
        });

        if (!jaExiste) {
          subList.add({'nome': novaSub, 'ativo': true});
          await FirebaseFirestore.instance
              .collection('categorias_fornecedor')
              .doc(docClasse.id)
              .update({'subgrupos': subList});
          await _carregarClassesIniciais();
        }

        setState(() {
          _subclasseSelecionada = novaSub;
          _carregando = false;
        });
      } catch (e) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar subclasse: $e')));
      }
    }
  }

  // Permite abrir qualquer numero passado
  Future<void> _abrirWhatsApp(String telefoneDigitado) async {
    String numero = telefoneDigitado.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um número válido.')));
      return;
    }
    if (!numero.startsWith('55')) numero = '55$numero';

    final Uri url = Uri.parse('https://wa.me/$numero');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final dados = {
      'clienteId': 'teste_textil',
      'nome': _razaoSocialController.text.trim(),
      'nomeFantasia': _nomeFantasiaController.text.trim(),
      'documento': _documentoController.text.trim(),
      'ie': _ieController.text.trim(),
      'contato': _telefoneEmpresaController.text.trim(),
      'whatsappVendedor': _telefoneVendedorController.text
          .trim(), // Salvando o Vendedor
      'email': _emailController.text.trim(),
      'site': _siteController.text.trim(),
      'cep': _cepController.text.trim(),
      'endereco': _enderecoController.text.trim(),
      'numero': _numeroController.text.trim(),
      'bairro': _bairroController.text.trim(),
      'cidade': _cidadeController.text.trim(),
      'estado': _estadoController.text.trim(),
      'observacoes': _obsController.text.trim(),
      'grupoNome': _classeSelecionadaNome,
      'subcategoria': _subclasseSelecionada,
      'ativo': true,
      'dataCadastro': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.fornecedorParaEditar == null) {
        await FirebaseFirestore.instance.collection('fornecedores').add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('fornecedores')
            .doc(widget.fornecedorParaEditar!.id)
            .update(dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fornecedorParaEditar == null
              ? 'Novo Parceiro'
              : 'Editar Parceiro',
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _secaoTitulo('Dados Identificadores'),
                    TextFormField(
                      controller: _razaoSocialController,
                      decoration: const InputDecoration(
                        labelText: 'Razão Social *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nomeFantasiaController,
                            decoration: const InputDecoration(
                              labelText: 'Nome Fantasia',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _documentoController,
                            decoration: const InputDecoration(
                              labelText: 'CNPJ / CPF',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _ieController,
                            decoration: const InputDecoration(
                              labelText: 'Insc. Estadual',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    _secaoTitulo('Classificação Industrial'),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _classeSelecionadaNome,
                            decoration: const InputDecoration(
                              labelText: 'Classe de Suprimento',
                              border: OutlineInputBorder(),
                            ),
                            items: _listaClasses.map((doc) {
                              return DropdownMenuItem(
                                value: doc['nome'].toString(),
                                child: Text(doc['nome']),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _classeSelecionadaNome = val;
                                _subclasseSelecionada = null;
                                _atualizarListaSubclasses(val!);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blueGrey,
                            size: 36,
                          ),
                          tooltip: 'Adicionar nova Classe',
                          onPressed: _atalhoNovaClasse,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _subclasseSelecionada,
                            decoration: const InputDecoration(
                              labelText: 'Subclasse (Gaveta)',
                              border: OutlineInputBorder(),
                            ),
                            items: _subclassesDisponiveis.map((nome) {
                              return DropdownMenuItem(
                                value: nome,
                                child: Text(nome),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _subclasseSelecionada = val),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.blueGrey,
                            size: 36,
                          ),
                          tooltip: 'Adicionar nova Subclasse',
                          onPressed: _atalhoNovaSubclasseRapida,
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    _secaoTitulo('Contato e Comunicação'),

                    // LINHA 1: WATSAPP EMPRESA
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _telefoneEmpresaController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp (Empresa Geral)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat, color: Colors.white),
                            onPressed: () =>
                                _abrirWhatsApp(_telefoneEmpresaController.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LINHA 2: WATSAPP VENDEDOR + EMAIL
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _telefoneVendedorController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp (Vendedor/Contato)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat, color: Colors.white),
                            onPressed: () => _abrirWhatsApp(
                              _telefoneVendedorController.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    _secaoTitulo('Localização Física'),
                    TextFormField(
                      controller: _enderecoController,
                      decoration: const InputDecoration(
                        labelText: 'Endereço (Rua/Av)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
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
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _cidadeController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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

                    const SizedBox(height: 25),
                    _secaoTitulo('Informações Adicionais'),
                    TextFormField(
                      controller: _obsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observações Gerais',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Center(
                        child: Text(
                          'CONFIRMAR CADASTRO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _secaoTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }
}
