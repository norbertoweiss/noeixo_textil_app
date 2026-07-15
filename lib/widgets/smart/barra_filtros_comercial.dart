import 'package:flutter/material.dart';

class BarraFiltrosComercial extends StatelessWidget {
  final String termoBusca;
  final String filtroAtivo;
  final String filtroStatus;
  final String filtroRepresentante;

  // Adicionamos parâmetros opcionais para injetar listas dinâmicas
  final List<String>? opcoesStatus;
  final List<String>? opcoesRepresentante;

  final ValueChanged<String> onBuscaChanged;
  final ValueChanged<String?> onAtivoChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onRepresentanteChanged;

  const BarraFiltrosComercial({
    super.key,
    required this.termoBusca,
    required this.filtroAtivo,
    required this.filtroStatus,
    required this.filtroRepresentante,
    this.opcoesStatus,
    this.opcoesRepresentante,
    required this.onBuscaChanged,
    required this.onAtivoChanged,
    required this.onStatusChanged,
    required this.onRepresentanteChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Se a tela não mandar listas customizadas, ele usa o seu padrão original da Gestão
    final listaRepresentante =
        opcoesRepresentante ?? const ['Todos', 'Lista Clientes Importada'];
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
              // Só mostra o filtro de Carteira se houver mais de uma opção
              if (listaRepresentante.length > 1) ...[
                Expanded(
                  flex: 2,
                  child: _construirDropdown(
                    rotulo: 'Carteira / Vendedor',
                    valor: filtroRepresentante,
                    itens: listaRepresentante,
                    onChanged: onRepresentanteChanged,
                    destaque:
                        filtroRepresentante == 'Lista Clientes Importada' ||
                        filtroRepresentante == 'Base Compartilhada',
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                flex: 1,
                child: _construirDropdown(
                  rotulo: 'Operação',
                  valor: filtroAtivo,
                  itens: const [
                    'Ativos',
                    'Inativos',
                    'Todos',
                  ], // Adicionado "Todos" para flexibilidade
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
    bool destaque = false,
  }) {
    // Validação de segurança: se o valor atual não estiver na lista (ex: troca de tela), força para a primeira opção
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
          style: TextStyle(
            color: destaque ? Colors.purple.shade700 : Colors.black87,
            fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
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
