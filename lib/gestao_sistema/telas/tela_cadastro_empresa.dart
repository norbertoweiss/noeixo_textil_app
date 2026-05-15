import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaCadastroEmpresa extends StatefulWidget {
  const TelaCadastroEmpresa({super.key});

  @override
  State<TelaCadastroEmpresa> createState() => _TelaCadastroEmpresaState();
}

class _TelaCadastroEmpresaState extends State<TelaCadastroEmpresa> {
  final _formKey = GlobalKey<FormState>();

  // Controllers da Nova Indústria
  final _razaoSocialCtrl = TextEditingController();
  final _nomeFantasiaCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();

  // Controllers do Primeiro Usuário (Dono da Fábrica)
  final _nomeMasterCtrl = TextEditingController();
  final _emailMasterCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _razaoSocialCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _cnpjCtrl.dispose();
    _nomeMasterCtrl.dispose();
    _emailMasterCtrl.dispose();
    super.dispose();
  }

  Future<void> _executarProvisionamento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;

    // Gera o ID único da nova empresa no Firestore
    final novaEmpresaRef = firestore.collection('empresas').doc();
    final String empresaId = novaEmpresaRef.id;

    // Prepara o documento do usuário master usando o e-mail como chave de isolamento
    final String emailFormatado = _emailMasterCtrl.text.trim().toLowerCase();
    final novoUsuarioRef = firestore.collection('usuarios').doc(emailFormatado);

    // Gravação Atômica (Batch): Garante consistência absoluta entre as tabelas
    final batch = firestore.batch();

    // Injeção na coleção de Empresas
    batch.set(novaEmpresaRef, {
      'id': empresaId,
      'razao_social': _razaoSocialCtrl.text.trim(),
      'nome_fantasia': _nomeFantasiaCtrl.text.trim(),
      'cnpj': _cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      'ativo': true,
      'data_cadastro': FieldValue.serverTimestamp(),
    });

    // Injeção na coleção de Usuários Vinculados
    batch.set(novoUsuarioRef, {
      'uid': '', // Será preenchido pelo Auth no primeiro login
      'nome': _nomeMasterCtrl.text.trim(),
      'email': emailFormatado,
      'empresa_id': empresaId, // O elo definitivo do Multi-Tenant
      'perfil': 'master',
      'ativo': true,
      'data_vinculo': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Nova indústria provisionada com sucesso!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro de gravação na infraestrutura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Admin - Nova Indústria'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DADOS CADASTRAIS DA FÁBRICA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nomeFantasiaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome Fantasia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.factory),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _razaoSocialCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Razão Social',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cnpjCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ',
                        border: OutlineInputBorder(),
                        hintText: '00.000.000/0000-00',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'GESTOR DA CONTA (PERFIL MASTER)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nomeMasterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Administrador',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailMasterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail Corporativo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'dono@industria.com.br',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v!.isEmpty) return 'Campo obrigatório';
                        if (!v.contains('@')) return 'E-mail inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade900,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _executarProvisionamento,
                      child: const Text(
                        'ATIVAR CONTA INDUSTRIAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
