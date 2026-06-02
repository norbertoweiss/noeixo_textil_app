import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  bool _ocultarSenha = true;
  bool _lembrarMe = false;
  bool _buscandoEmpresa = false;
  bool _processandoAlteracao = false;
  bool _processandoLogin = false;

  String _nomeEmpresaExibicao = 'NoEixo Têxtil';
  String _fraseEmpresaExibicao = 'Bem-vindo ao comando da sua produção';
  bool _empresaBloqueada = false;
  bool _forcarTrocaSenhaInterface = false;

  final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_detectarEmailEmpresa);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    _emailFocus.removeListener(_detectarEmailEmpresa);
    _emailFocus.dispose();
    super.dispose();
  }

  void _detectarEmailEmpresa() async {
    if (!_emailFocus.hasFocus) {
      final email = _emailCtrl.text.trim().toLowerCase();
      if (_emailRegex.hasMatch(email)) {
        setState(() => _buscandoEmpresa = true);
        try {
          var userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(email)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            final dadosUser = userDoc.data()!;
            final String perfil = dadosUser['perfil'] ?? '';
            final bool primeiroAcesso = dadosUser['primeiro_acesso'] ?? false;
            final String empresaId = dadosUser['empresa_id'] ?? '';

            String nomeEmpresa = 'NoEixo Têxtil';
            String fraseEmpresa =
                'Por favor, insira a sua credencial de acesso.';

            if (empresaId.isNotEmpty) {
              final empresaDoc = await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .get();
              if (empresaDoc.exists && empresaDoc.data() != null) {
                final empData = empresaDoc.data()!;
                nomeEmpresa = empData['nome_fantasia'] ?? 'NoEixo Têxtil';
                fraseEmpresa =
                    empData['frase_customizada'] ??
                    'Por favor, insira a sua credencial de acesso.';
                _empresaBloqueada = !(empData['ativo'] ?? true);
              }
            }

            if (perfil == 'admin_noeixo') {
              nomeEmpresa = 'NoEixo Sistemas';
              fraseEmpresa = 'Painel do Administrador Geral da Holding.';
            }

            if (primeiroAcesso) {
              fraseEmpresa =
                  '🔑 Primeiro acesso detetado! Digite a senha provisória para registar a sua senha definitiva.';
            }

            setState(() {
              _nomeEmpresaExibicao = nomeEmpresa;
              _fraseEmpresaExibicao = fraseEmpresa;
            });
            return;
          } else {
            final empresaQuery = await FirebaseFirestore.instance
                .collection('empresas')
                .where('email_contato', isEqualTo: email)
                .limit(1)
                .get();
            if (empresaQuery.docs.isNotEmpty) {
              final empData = empresaQuery.docs.first.data();
              setState(() {
                _nomeEmpresaExibicao =
                    empData['nome_fantasia'] ?? 'NoEixo Têxtil';
                _fraseEmpresaExibicao =
                    '🔑 Primeiro acesso detetado! Digite a senha provisória para ativar a sua conta.';
                _empresaBloqueada = !(empData['ativo'] ?? true);
              });
            }
          }
        } catch (e) {
          debugPrint('Aviso de varredura: $e');
        } finally {
          setState(() => _buscandoEmpresa = false);
        }
      }
    }
  }

  void _executarLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    final senha = _senhaCtrl.text.trim();

    if (_empresaBloqueada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Conta Suspensa. Contacte a NoEixo Sistemas.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _processandoLogin = true);

    // CHAVE MESTRA
    if (email == 'norbertoweiss@gmail.com' &&
        (senha == '#Nowe0909' ||
            senha == 'noeixo123' ||
            senha == 'NoEixo123')) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } catch (_) {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: senha,
          );
        } catch (_) {}
      }
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TelaPrincipal(emailUser: email),
          ),
        );
      return;
    }

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(email)
          .get();
      final dadosUserSeguro = userDoc.data() ?? {};

      // 1. Verificação de Primeiro Acesso
      if (userDoc.exists) {
        bool primeiroAcesso = dadosUserSeguro['primeiro_acesso'] ?? false;
        String senhaGravada = dadosUserSeguro['senha_acesso'] ?? '';

        if (senhaGravada.isEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(email)
              .update({'senha_acesso': 'NoEixo123', 'primeiro_acesso': true});
          senhaGravada = 'NoEixo123';
          primeiroAcesso = true;
        }

        if (primeiroAcesso && senha == senhaGravada) {
          setState(() {
            _forcarTrocaSenhaInterface = true;
            _fraseEmpresaExibicao =
                '⚠️ Bloqueio de Segurança: Registe a sua nova senha mestre corporativa.';
            _processandoLogin = false;
          });
          return;
        }
      } else {
        // Auto-cadastro para Gestor
        final empresaQuery = await FirebaseFirestore.instance
            .collection('empresas')
            .where('email_contato', isEqualTo: email)
            .limit(1)
            .get();
        if (empresaQuery.docs.isNotEmpty) {
          final empDoc = empresaQuery.docs.first;
          final empData = empDoc.data();
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(email)
              .set({
                'nome': empData['nome_administrador'] ?? 'Gestor Master',
                'email': email,
                'whatsapp': empData['whatsapp_contato'] ?? '',
                'empresa_id': empDoc.id,
                'perfil': 'master',
                'senha_acesso': 'NoEixo123',
                'primeiro_acesso': true,
                'ativo': true,
                'data_vinculo': FieldValue.serverTimestamp(),
              });
          setState(() {
            _forcarTrocaSenhaInterface = true;
            _fraseEmpresaExibicao =
                '⚠️ Bloqueio de Segurança: Registe a sua nova senha mestre corporativa.';
            _processandoLogin = false;
          });
          return;
        }
      }

      // =================================================================================
      // TENTATIVA DE LOGIN NO GOOGLE COM FALLBACK DE CONTINUIDADE DE NEGÓCIO
      // =================================================================================
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TelaPrincipal(emailUser: email),
            ),
          );
      } catch (e) {
        // FALLBACK: Se o Google falhar por channel-error, restrições ou cache corrompido,
        // validamos no banco e garantimos a entrada para não parar a fábrica.
        if (userDoc.exists && dadosUserSeguro['senha_acesso'] == senha) {
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: senha,
            );
          } catch (_) {}

          if (mounted)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TelaPrincipal(emailUser: email),
              ),
            );
        } else {
          String msgErro = '❌ E-mail ou palavra-passe incorretos.';
          if (e is FirebaseAuthException && e.code == 'operation-not-allowed') {
            msgErro =
                '❌ ALERTA: O login E-mail/Senha está DESLIGADO no Firebase.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msgErro),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Falha estrutural de conexão: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _processandoLogin = false);
    }
  }

  void _salvarNovaSenhaDefinitiva() async {
    if (_novaSenhaCtrl.text.isEmpty || _novaSenhaCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A senha precisa de ter no mínimo 6 dígitos.'),
        ),
      );
      return;
    }

    if (_novaSenhaCtrl.text != _confirmarSenhaCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas digitadas não coincidem.')),
      );
      return;
    }

    setState(() => _processandoAlteracao = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final novaSenha = _novaSenhaCtrl.text.trim();

    try {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: novaSenha,
        );
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: 'NoEixo123',
            );
            await FirebaseAuth.instance.currentUser?.updatePassword(novaSenha);
          } catch (_) {}
        }
      }

      // GRAVA A SENHA NO BANCO PARA O FALLBACK CONTINUAR A FUNCIONAR SE O GOOGLE FALHAR
      await FirebaseFirestore.instance.collection('usuarios').doc(email).update(
        {'senha_acesso': novaSenha, 'primeiro_acesso': false},
      );

      if (mounted) {
        setState(() {
          _forcarTrocaSenhaInterface = false;
          _senhaCtrl.clear();
          _novaSenhaCtrl.clear();
          _confirmarSenhaCtrl.clear();
          _fraseEmpresaExibicao =
              '✅ Senha Atualizada! Entre agora com as suas novas credenciais.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Nova senha registada! Faça o login.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar nova credencial: $e')),
      );
    } finally {
      setState(() => _processandoAlteracao = false);
    }
  }

  void _dispararRecuperacaoSenha() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Digite um e-mail válido no campo acima primeiro para recuperar a senha.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ E-mail de redefinição enviado! Verifique a sua caixa de entrada/spam.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao enviar recuperação: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    double larguraJanela = MediaQuery.of(context).size.width;
    double larguraCard = larguraJanela > 600 ? 450 : larguraJanela * 0.9;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueGrey.shade100,
              const Color(0xFFF8FAFC),
              const Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: larguraCard,
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _forcarTrocaSenhaInterface
                                      ? Colors.amber.shade50
                                      : (_empresaBloqueada
                                            ? Colors.red.shade50
                                            : Colors.blueGrey.shade50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _forcarTrocaSenhaInterface
                                      ? Icons.security_rounded
                                      : (_empresaBloqueada
                                            ? Icons.lock_outline_rounded
                                            : Icons.architecture_rounded),
                                  size: 42,
                                  color: _forcarTrocaSenhaInterface
                                      ? Colors.amber.shade900
                                      : (_empresaBloqueada
                                            ? Colors.red.shade900
                                            : Colors.blueGrey.shade900),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _nomeEmpresaExibicao,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _empresaBloqueada
                                      ? Colors.red.shade900
                                      : Colors.blueGrey.shade900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buscandoEmpresa
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _fraseEmpresaExibicao,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _forcarTrocaSenhaInterface
                                            ? Colors.amber.shade900
                                            : (_empresaBloqueada
                                                  ? Colors.red.shade700
                                                  : Colors.blueGrey.shade600),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        if (_forcarTrocaSenhaInterface) ...[
                          Text(
                            'Nova Senha Definitiva',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _novaSenhaCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Mínimo 6 caracteres',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Confirmar Nova Senha',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmarSenhaCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Repita a senha',
                              prefixIcon: Icon(Icons.lock_reset_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _processandoAlteracao
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      54,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _salvarNovaSenhaDefinitiva,
                                  child: const Text(
                                    'REGISTAR SENHA DEFINITIVA',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ] else ...[
                          Text(
                            'E-mail Corporativo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'exemplo@empresa.com',
                              prefixIcon: const Icon(
                                Icons.mail_outline_rounded,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Insira o seu e-mail';
                              if (!_emailRegex.hasMatch(v))
                                return 'Formato inválido. Use nome@dominio.com';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Senha de Acesso',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _senhaCtrl,
                            obscureText: _ocultarSenha,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_open_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarSenha
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _ocultarSenha = !_ocultarSenha,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Insira a sua senha' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _lembrarMe,
                                      activeColor: Colors.blueGrey.shade900,
                                      onChanged: (v) =>
                                          setState(() => _lembrarMe = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lembrar de mim',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _dispararRecuperacaoSenha,
                                child: Text(
                                  'Esqueceu a senha?',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _processandoLogin
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey.shade900,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      54,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _executarLogin,
                                  child: const Text(
                                    'ENTRAR NO COMANDO',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
