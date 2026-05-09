import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormCategoriaFornecedor extends StatefulWidget {
  final DocumentSnapshot? categoriaParaEditar;
  const FormCategoriaFornecedor({super.key, this.categoriaParaEditar});

  @override
  State<FormCategoriaFornecedor> createState() =>
      _FormCategoriaFornecedorState();
}

class _FormCategoriaFornecedorState extends State<FormCategoriaFornecedor> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _subgrupoController = TextEditingController();

  List<Map<String, dynamic>> _subgrupos = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoriaParaEditar != null) {
      final data = widget.categoriaParaEditar!.data() as Map<String, dynamic>;
      _nomeController.text = data['nome'] ?? '';
      _descricaoController.text = data['descricao'] ?? '';

      final subList = data['subgrupos'] ?? [];
      _subgrupos = subList.map<Map<String, dynamic>>((e) {
        if (e is String) return {'nome': e, 'ativo': true};
        return Map<String, dynamic>.from(e);
      }).toList();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _subgrupoController.dispose();
    super.dispose();
  }

  void _adicionarSubgrupo() {
    final texto = _subgrupoController.text.trim();
    if (texto.isNotEmpty) {
      bool existe = _subgrupos.any(
        (s) => s['nome'].toString().toLowerCase() == texto.toLowerCase(),
      );
      if (!existe) {
        setState(() {
          _subgrupos.add({'nome': texto, 'ativo': true});
          _subgrupoController.clear();
        });
      }
    }
  }

  Future<void> _editarSubgrupo(int index) async {
    TextEditingController editCtrl = TextEditingController(
      text: _subgrupos[index]['nome'],
    );
    String? novoNome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Subclasse'),
        content: TextField(controller: editCtrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, editCtrl.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novoNome != null && novoNome.trim().isNotEmpty) {
      setState(() => _subgrupos[index]['nome'] = novoNome.trim());
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final dados = {
      'clienteId': 'teste_textil',
      'nome': _nomeController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'subgrupos': _subgrupos,
      'ativo': true,
    };

    try {
      if (widget.categoriaParaEditar == null) {
        await FirebaseFirestore.instance
            .collection('categorias_fornecedor')
            .add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('categorias_fornecedor')
            .doc(widget.categoriaParaEditar!.id)
            .update(dados);
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classe de Suprimentos')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Classe',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 15),
                    // CAMPO EXPLICATIVO PARA APOIO AO USUÁRIO
                    TextFormField(
                      controller: _descricaoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Finalidade / Onde o sistema usa?',
                        hintText: 'Ex: Tudo o que compõe a Ficha Técnica...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Subclasses (Gavetas)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _subgrupoController,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Fios e Malhas',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blueGrey,
                          ),
                          onPressed: _adicionarSubgrupo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subgrupos.length,
                      itemBuilder: (context, index) {
                        final sub = _subgrupos[index];
                        return ListTile(
                          title: Text(
                            sub['nome'],
                            style: TextStyle(
                              decoration: sub['ativo']
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editarSubgrupo(index),
                              ),
                              Switch(
                                value: sub['ativo'],
                                onChanged: (v) => setState(
                                  () => _subgrupos[index]['ativo'] = v,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _salvar,
                      child: const Text('GUARDAR CLASSE'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
