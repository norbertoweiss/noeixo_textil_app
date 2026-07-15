import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importações relativas das telas que estão na mesma pasta
import 'tela_laboratorio_precos.dart';
import 'tela_catalogo_vendas.dart';
import 'tela_meus_pedidos.dart';
import 'tela_carteira_clientes.dart';
import 'tela_gestao_regioes.dart';
import 'tela_cadastro_vendedor.dart';

// ============================================================================
// IMPORTAÇÃO DA NOVA TELA DE GESTÃO (Na nova subpasta)
// ============================================================================
import 'gestao/tela_gestao_comercial.dart';

class TelaComercialMenu extends StatefulWidget {
  final String empresaId;
  const TelaComercialMenu({super.key, required this.empresaId});

  @override
  State<TelaComercialMenu> createState() => _TelaComercialMenuState();
}

class _TelaComercialMenuState extends State<TelaComercialMenu> {
  bool _carregando = true;
  String _perfilUsuario = 'vendedor'; // Padrão mais restrito por segurança

  @override
  void initState() {
    super.initState();
    _carregarPerfilSeguranca();
  }

  Future<void> _carregarPerfilSeguranca() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.email)
            .get();

        if (doc.exists && doc.data() != null) {
          setState(() {
            _perfilUsuario = doc.data()!['perfil'] ?? 'vendedor';
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao validar credenciais no menu: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _botaoMenuResponsivo(
    BuildContext context,
    String titulo,
    IconData icone,
    Color cor,
    Widget destino,
  ) {
    double largura = MediaQuery.of(context).size.width;
    double tamanhoIcone = largura > 600 ? 30 : 40;
    double tamanhoFonte = largura > 600 ? 12 : 14;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destino),
      ),
      child: Card(
        elevation: 4,
        color: cor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: tamanhoIcone, color: Colors.white),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: tamanhoFonte,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    // REGRA DE NEGÓCIO: Quem é gestor?
    final bool isGestor =
        _perfilUsuario == 'master' ||
        _perfilUsuario == 'admin_noeixo' ||
        _perfilUsuario == 'admin' ||
        _perfilUsuario == 'gestor';

    double largura = MediaQuery.of(context).size.width;
    int colunas = largura > 800 ? 4 : 2;

    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: colunas,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        // BOTÃO OCULTO PARA VENDEDORES
        if (isGestor)
          _botaoMenuResponsivo(
            context,
            'Central de Preços',
            Icons.request_quote,
            Colors.amber.shade700,
            TelaLaboratorioPrecos(empresaId: widget.empresaId),
          ),

        // BOTÕES PÚBLICOS (COMERCIAL GERAL)
        _botaoMenuResponsivo(
          context,
          'Catálogo de Vendas',
          Icons.storefront,
          Colors.deepOrange,
          TelaCatalogoVendas(empresaId: widget.empresaId),
        ),
        _botaoMenuResponsivo(
          context,
          'Meus Pedidos',
          Icons.shopping_bag,
          Colors.blue.shade600,
          const TelaMeusPedidos(),
        ),
        _botaoMenuResponsivo(
          context,
          'Carteira & CRM',
          Icons.badge,
          Colors.indigo,
          TelaCarteiraClientes(empresaId: widget.empresaId),
        ),

        // BOTÕES OCULTOS PARA VENDEDORES
        if (isGestor) ...[
          _botaoMenuResponsivo(
            context,
            'Regiões & Territórios',
            Icons.map,
            Colors.deepPurple,
            const TelaGestaoRegioes(),
          ),
          _botaoMenuResponsivo(
            context,
            'Cadastro de Vendedores',
            Icons.badge_outlined,
            Colors.teal,
            TelaCadastroVendedor(empresaId: widget.empresaId),
          ),
          // =================================================================
          // NOVO BOTÃO: GESTÃO DE CARTEIRAS (ACESSÍVEL APENAS A GESTORES)
          // =================================================================
          _botaoMenuResponsivo(
            context,
            'Gestão de Carteiras',
            Icons.groups,
            Colors.blueGrey,
            TelaGestaoComercial(empresaId: widget.empresaId),
          ),
        ],
      ],
    );
  }
}
