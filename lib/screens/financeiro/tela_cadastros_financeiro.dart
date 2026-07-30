import 'package:flutter/material.dart';
import 'package:noeixo_textil_app/screens/comercial/gestao/tela_lista_politicas_comerciais.dart';
import 'package:noeixo_textil_app/screens/configuracoes/tela_configuracao_checklist.dart';
import 'tela_lista_formas_pagamento.dart';
import 'tela_lista_condicoes_pagamento.dart';

// ATENÇÃO: Ajuste este caminho de importação conforme a estrutura de pastas do seu projeto

class TelaCadastrosFinanceiro extends StatelessWidget {
  final String empresaId; // <-- ADICIONADO PARA O MULTI-TENANT

  const TelaCadastrosFinanceiro({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastros Financeiros'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==============================================================
          // NOVO: ACESSO À MÁQUINA DE POLÍTICAS COMERCIAIS
          // ==============================================================
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.gavel, color: Colors.white),
            ),
            title: const Text(
              'Políticas Comerciais e Comissões',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Configure regras de desconto e escalonamento de comissões',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TelaListaPoliticasComerciais(empresaId: empresaId),
                ),
              );
            },
          ),
          const Divider(),

          // ==============================================================
          // ACESSO AO CONSTRUTOR DE CHECKLIST DO FINANCEIRO
          // ==============================================================
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Icon(Icons.rule_folder, color: Colors.white),
            ),
            title: const Text(
              'Regras de Aprovação (Checklist)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Configure as perguntas de análise de crédito',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaConfiguracaoChecklist(
                    // <-- "const" REMOVIDO PARA PODER RECEBER A VARIÁVEL
                    empresaId: empresaId, // <-- REPASSANDO PARA O CHECKLIST
                    setorAcesso: 'Financeiro',
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // ==============================================================
          // FORMAS DE PAGAMENTO
          // ==============================================================
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.account_balance_wallet, color: Colors.white),
            ),
            title: const Text(
              'Formas de Pagamento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Dinheiro, PIX, Boleto, Cartão...'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaListaFormasPagamento(),
                ),
              );
            },
          ),
          const Divider(),

          // ==============================================================
          // CONDIÇÕES DE PAGAMENTO (PRAZOS E MATEMÁTICA)
          // ==============================================================
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.date_range, color: Colors.white),
            ),
            title: const Text(
              'Condições de Pagamento (Prazos)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('À Vista, 30/60/90, Parcelamentos...'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaListaCondicoesPagamento(),
                ),
              );
            },
          ),
          const Divider(),

          // ==============================================================
          // CONTAS BANCÁRIAS (FUTURO)
          // ==============================================================
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.account_balance, color: Colors.white),
            ),
            title: const Text(
              'Contas Bancárias',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            subtitle: const Text('Em breve'),
            trailing: const Icon(Icons.lock, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Módulo em desenvolvimento.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
