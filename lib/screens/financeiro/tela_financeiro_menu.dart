import 'package:flutter/material.dart';
import 'tela_cadastros_financeiro.dart';
import 'tela_contas_a_pagar.dart'; // Importação da nova tela de controle

class TelaFinanceiroMenu extends StatelessWidget {
  const TelaFinanceiroMenu({super.key});

  Widget _botaoMenu(
    BuildContext context,
    String titulo,
    IconData icone,
    Color cor,
    Widget? destino,
  ) {
    return InkWell(
      onTap: destino != null
          ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destino),
            )
          : () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Módulo em desenvolvimento.')),
            ),
      child: Card(
        elevation: 4,
        color: cor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double largura = MediaQuery.of(context).size.width;
    int colunas = largura > 800 ? 4 : 2;

    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: colunas,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _botaoMenu(
          context,
          'Dashboard Financeiro',
          Icons.insert_chart,
          Colors.blueGrey.shade800,
          null,
        ),
        // O botão agora aponta para a Tela de Contas a Pagar
        _botaoMenu(
          context,
          'Contas a Pagar',
          Icons.money_off,
          Colors.red.shade700,
          const TelaContasAPagar(),
        ),
        _botaoMenu(
          context,
          'Contas a Receber',
          Icons.attach_money,
          Colors.green.shade700,
          null,
        ),
        _botaoMenu(
          context,
          'Cadastros Financeiros',
          Icons.settings_applications,
          Colors.blueGrey.shade600,
          const TelaCadastrosFinanceiro(),
        ),
      ],
    );
  }
}
