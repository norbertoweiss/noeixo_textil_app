import 'package:flutter/material.dart';
import 'tela_lista_formas_pagamento.dart';
import 'tela_lista_condicoes_pagamento.dart'; // NOVA IMPORTAÇÃO

class TelaCadastrosFinanceiro extends StatelessWidget {
  const TelaCadastrosFinanceiro({super.key});

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
              // AGORA ABRE A LISTA DE CONDIÇÕES!
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaListaCondicoesPagamento(),
                ),
              );
            },
          ),
          const Divider(),
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
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
