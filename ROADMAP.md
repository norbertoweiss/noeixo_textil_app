# 🗺️ ROADMAP - NoEixo Têxtil

## 🚀 Fase 1: MVP (Produto Mínimo Viável) - Em Andamento
- [x] Cadastros Base Dinâmicos (Cores, Grades, Tecidos)
- [x] Módulo de Suprimentos (Insumos, Fornecedores)
- [x] Módulo de Estoque e Financeiro (Contas a Pagar)
- [x] Engenharia: Cadastro de Processos e Produtos (Pai/Filho)
- [x] Engenharia: Ficha Técnica (Estrutura e Identificação)
- [ ] Engenharia: Motor de Cálculo de Insumos e Roteiro de Processos
- [ ] PCP: Ordem de Corte e Maestro de Produção

## ⚙️ Fase 2: Escala e Automação
- [ ] Integração do Financeiro com Contas a Receber
- [ ] Dashboards Operacionais reais (Gráficos)
- [ ] Controle de Facções Externas (Entrada/Saída de remessas)

## 💎 Fase 3: Inovações Premium (Monetização)
- [ ] **Módulo Digiflash Mobile (Visão Computacional):**
  - **Objetivo:** Calcular a área (m²) e perímetro dos moldes físicos usando a câmera do celular.
  - **Tecnologia:** Integração do Flutter Camera com script OpenCV (Python) rodando no Firebase Cloud Functions.
  - **Lógica Matemática:** Uso de um Gabarito de Referência (ex: Folha A4 ou Marcador ArUco) para correção de perspectiva (Homografia) e cálculo de Pixels Per Metric (PPM) após a binarização da imagem.