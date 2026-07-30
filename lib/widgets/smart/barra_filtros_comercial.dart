import 'package:flutter/material.dart';

// IMPORTAÇÃO DO NOSSO NOVO BLOCO DE LEGO
import 'filtro_vendedor_multi.dart';

class BarraFiltrosComercial extends StatelessWidget {
  final String empresaId;
  final String termoBusca;
  final String filtroAtivo;
  final String filtroStatus;

  final List<String> filtroRepresentantes;
  final List<String>? opcoesStatus;

  // NOVA TRAVA DE SEGURANÇA: Controla se o filtro de carteiras aparece na tela
  final bool exibirFiltroVendedor;

  final ValueChanged<String> onBuscaChanged;
  final ValueChanged<String?> onAtivoChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<List<String>> onRepresentantesChanged;

  const BarraFiltrosComercial({
    super.key,
    required this.empresaId,
    required this.termoBusca,
    required this.filtroAtivo,
    required this.filtroStatus,
    required this.filtroRepresentantes,
    this.opcoesStatus,
    this.exibirFiltroVendedor = true, // Por padrão, ele mostra
    required this.onBuscaChanged,
    required this.onAtivoChanged,
    required this.onStatusChanged,
    required this.onRepresentantesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final listaStatus =
        opcoesStatus ??
        const ['Todos', 'Pendente Enriquecimento', 'Aprovado', 'Bloqueado'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar Razão Social, Fantasia, CNPJ ou IE...',
              prefixIcon: const Icon(Icons.search, color: Colors.indigo),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onBuscaChanged,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // SÓ EXIBE SE A TELA AUTORIZAR (Evita que o vendedor veja carteira alheia)
              if (exibirFiltroVendedor) ...[
                Expanded(
                  flex: 2,
                  child: FiltroVendedorMulti(
                    empresaId: empresaId,
                    vendedoresSelecionados: filtroRepresentantes,
                    onChanged: onRepresentantesChanged,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                flex: 1,
                child: _construirDropdown(
                  rotulo: 'Operação',
                  valor: filtroAtivo,
                  itens: const ['Ativos', 'Inativos', 'Todos'],
                  onChanged: onAtivoChanged,
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                flex: 1,
                child: _construirDropdown(
                  rotulo: 'Crédito',
                  valor: filtroStatus,
                  itens: listaStatus,
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirDropdown({
    required String rotulo,
    required String valor,
    required List<String> itens,
    required ValueChanged<String?> onChanged,
  }) {
    final valorSeguro = itens.contains(valor) ? valor : itens.first;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: const TextStyle(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          isExpanded: true,
          value: valorSeguro,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: itens.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
