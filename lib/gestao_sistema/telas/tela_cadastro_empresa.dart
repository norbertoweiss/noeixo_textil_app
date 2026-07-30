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
  final _slugCtrl = TextEditingController();
  final _fraseCustomizadaCtrl = TextEditingController(
    text: 'Por favor, insira sua senha administrativa de fábrica.',
  );

  // Controllers do Primeiro Usuário (Dono da Fábrica)
  final _nomeMasterCtrl = TextEditingController();
  final _emailMasterCtrl = TextEditingController();
  final _whatsappMasterCtrl = TextEditingController();

  bool _isLoading = false;

  final Map<String, bool> _modulosContratados = {
    'Dashboard': true,
    'Suprimentos': false,
    'Comercial': false,
    'Engenharia': false,
    'PCP': false,
    'Produção': false,
    'Logística': false,
    'Financeiro': false,
    'RH': false,
  };

  @override
  void dispose() {
    _razaoSocialCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _cnpjCtrl.dispose();
    _slugCtrl.dispose();
    _fraseCustomizadaCtrl.dispose();
    _nomeMasterCtrl.dispose();
    _emailMasterCtrl.dispose();
    _whatsappMasterCtrl.dispose();
    super.dispose();
  }

  void _gerarSlug(String valor) {
    String slug = valor
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '-');

    slug = slug.replaceAll(RegExp(r'-+'), '-');
    if (slug.endsWith('-')) slug = slug.substring(0, slug.length - 1);

    _slugCtrl.text = slug;
  }

  Future<void> _executarProvisionamento() async {
    if (!_formKey.currentState!.validate()) return;

    bool temModuloAtivo = _modulosContratados.values.any((v) => v == true);
    if (!temModuloAtivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um módulo para liberar.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;

    final novaEmpresaRef = firestore.collection('empresas').doc();
    final String empresaId = novaEmpresaRef.id;

    final String emailFormatado = _emailMasterCtrl.text.trim().toLowerCase();
    final novoUsuarioRef = firestore.collection('usuarios').doc(emailFormatado);

    List<String> modulosLiberados = _modulosContratados.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final batch = firestore.batch();

    // Gravação da Empresa com a Frase de Boas-Vindas
    batch.set(novaEmpresaRef, {
      'id': empresaId,
      'razao_social': _razaoSocialCtrl.text.trim(),
      'nome_fantasia': _nomeFantasiaCtrl.text.trim(),
      'cnpj': _cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      'slug_acesso': _slugCtrl.text,
      'frase_customizada': _fraseCustomizadaCtrl.text.trim(),
      'modulos_ativos': modulosLiberados,
      'faturamento_saas': 1250.00,
      'ramo': 'Têxtil',
      'ativo': true,
      'data_cadastro': FieldValue.serverTimestamp(),
    });

    // Gravação do Usuário Master com as flags de Segurança e Senha Provisória
    batch.set(novoUsuarioRef, {
      'uid': '',
      'nome': _nomeMasterCtrl.text.trim(),
      'email': emailFormatado,
      'whatsapp': _whatsappMasterCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      'empresa_id': empresaId,
      'perfil': 'master',
      'senha_acesso': 'NoEixo123', // Senha genérica padrão de primeiro acesso
      'primeiro_acesso': true, // Trava mestre que forçará a troca de senha
      'ativo': true,
      'data_vinculo': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🚀 Conta Industrial criada! Senha provisória: NoEixo123',
            ),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro de gravação: $e'),
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
                      onChanged: _gerarSlug,
                      decoration: const InputDecoration(
                        labelText: 'Nome Fantasia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.factory),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _slugCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Link de Acesso Personalizado (Automático)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                        prefixText: 'app.noeixo.com.br/ ',
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fraseCustomizadaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Frase de Boas-Vindas da Tela de Login',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment_bank_outlined),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Insira uma frase inspiradora' : null,
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
                      'LIBERAÇÃO DE MÓDULOS (CONTRATO)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _modulosContratados.keys.map((String chave) {
                        return IntrinsicWidth(
                          child: CheckboxListTile(
                            title: Text(
                              chave,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: _modulosContratados[chave],
                            activeColor: Colors.indigo,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged: chave == 'Dashboard'
                                ? null
                                : (bool? valor) {
                                    setState(() {
                                      _modulosContratados[chave] = valor!;
                                    });
                                  },
                          ),
                        );
                      }).toList(),
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
                      controller: _whatsappMasterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp do Gestor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android),
                        hintText: '(00) 00000-0000',
                      ),
                      keyboardType: TextInputType.phone,
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
                        'ATIVAR CONTA COMERCIAL',
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
