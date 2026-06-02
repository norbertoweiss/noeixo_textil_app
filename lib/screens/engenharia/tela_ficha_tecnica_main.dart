import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aba_identificacao_comercial.dart';
import 'aba_insumos.dart';
import 'aba_processos.dart';
import 'aba_qualidade.dart';

class TelaFichaTecnicaMain extends StatefulWidget {
  final String empresaId;
  final String? fichaId;
  final Map<String, dynamic>? dadosAtuais;

  const TelaFichaTecnicaMain({
    super.key,
    required this.empresaId,
    this.fichaId,
    this.dadosAtuais,
  });

  @override
  State<TelaFichaTecnicaMain> createState() => TelaFichaTecnicaMainState();
}

class TelaFichaTecnicaMainState extends State<TelaFichaTecnicaMain> {
  final bool _isAdmin = true;
  bool _isLoading = false;
  bool _houveAlteracao = false;

  // --- O CÉREBRO: VARIÁVEIS COMPARTILHADAS ---
  String? produtoSelecionadoId;
  String? produtoNome;
  String? referencia;
  String? gradeSelecionadaId;
  String? gradeNome;
  List<String> tamanhosGrade = [];
  List<String> coresComerciaisDisponiveis = [];

  // FASE 2, 3 e 4: Dados consolidados das abas filhas
  List<Map<String, dynamic>> insumosConsumidos = [];
  List<Map<String, dynamic>> processosRoteiro = [];
  List<Map<String, dynamic>> itensQualidade = [];

  @override
  void initState() {
    super.initState();
    if (widget.dadosAtuais != null) {
      produtoSelecionadoId = widget.dadosAtuais!['produtoId'];
      produtoNome = widget.dadosAtuais!['produtoNome'];
      referencia = widget.dadosAtuais!['referencia'];
      gradeSelecionadaId = widget.dadosAtuais!['gradeId'];
      gradeNome = widget.dadosAtuais!['gradeNome'];

      tamanhosGrade = List<String>.from(widget.dadosAtuais!['tamanhos'] ?? []);
      insumosConsumidos = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['insumos'] ?? [],
      );
      processosRoteiro = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['processos'] ?? [],
      );
      itensQualidade = List<Map<String, dynamic>>.from(
        widget.dadosAtuais!['qualidade'] ?? [],
      );
      coresComerciaisDisponiveis = List<String>.from(
        widget.dadosAtuais!['coresComerciais'] ?? [],
      );
    }
  }

  void registrarAlteracao() {
    if (!mounted) return;
    setState(() {
      _houveAlteracao = true;
    });
  }

  Future<void> _salvarFichaCompleta() async {
    if (produtoSelecionadoId == null || gradeSelecionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecione um Produto e uma Grade na aba Identificação.',
          ),
        ),
      );
      return;
    }
    if (coresComerciaisDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione pelo menos uma cor comercial permitida para este produto.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final dadosParaNuvem = {
      'empresa_id': widget.empresaId,
      'produtoId': produtoSelecionadoId,
      'produtoNome': produtoNome,
      'referencia': referencia,
      'gradeId': gradeSelecionadaId,
      'gradeNome': gradeNome,
      'tamanhos': tamanhosGrade,
      'insumos': insumosConsumidos,
      'processos': processosRoteiro,
      'qualidade': itensQualidade,
      'coresComerciais': coresComerciaisDisponiveis,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.fichaId == null) {
        dadosParaNuvem['criadoEm'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('fichas_tecnicas')
            .add(dadosParaNuvem);
      } else {
        await FirebaseFirestore.instance
            .collection('fichas_tecnicas')
            .doc(widget.fichaId)
            .update(dadosParaNuvem);
      }
      _houveAlteracao = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ficha consolidada com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _avisarSaidaSemSalvar() async {
    if (!_houveAlteracao) return true;
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção!', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Você tem alterações não salvas. Deseja sair e perder o trabalho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return sair ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: WillPopScope(
        onWillPop: _avisarSaidaSemSalvar,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.fichaId == null ? 'Nova Ficha Técnica' : 'Editar Ficha',
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(
                  right: 8.0,
                  top: 8.0,
                  bottom: 8.0,
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'SALVAR E SAIR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _salvarFichaCompleta,
                ),
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  text: 'Identificação Comercial',
                  icon: Icon(Icons.info_outline),
                ),
                Tab(
                  text: 'Insumos (BOM)',
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                Tab(text: 'Processos', icon: Icon(Icons.account_tree_outlined)),
                Tab(text: 'Qualidade', icon: Icon(Icons.verified_outlined)),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    AbaIdentificacaoComercial(controller: this),
                    AbaInsumos(controller: this),
                    AbaProcessos(controller: this),
                    AbaQualidade(controller: this),
                  ],
                ),
        ),
      ),
    );
  }
}
