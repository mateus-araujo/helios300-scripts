# Helios 300 Thermal Management Scripts

Scripts para gerenciar performance térmica do Acer Predator Helios 300 (i7-11800H, RTX 3070 Max-Q).

## Pré-requisitos

| Programa | Download | Função |
|----------|----------|--------|
| Throttlestop 9.6+ | TechPowerUp | Undervolt + Power Limits CPU |
| MSI Afterburner | MSI Website | Undervolt GPU |
| NoteBook FanControl | GitHub | Curva de fans customizada |

## Estrutura

```
helios300-scripts/
├── toggle-mode.ps1          # Script principal
├── install-paths.ps1        # Configuração de caminhos
├── profiles/
│   ├── throttlestop/        # Perfis de CPU (gaming.ini, silent.ini)
│   ├── nbfc/                # Curvas de fan (gaming.json, silent.json)
│   └── afterburner/         # Instruções GPU
└── README.md
```

## Uso

```powershell
# Alternar modos:
.\toggle-mode.ps1 -Mode gaming   # Performance com temperatura controlada
.\toggle-mode.ps1 -Mode silent   # Silencioso para escritório
.\toggle-mode.ps1 -Mode auto     # Volta ao padrão de fábrica

# OU use o menu interativo (só rodar sem parâmetros):
.\toggle-mode.ps1
```

## O que cada modo faz

### Gaming Mode
- Undervolt CPU: -100mV core, -90mV cache
- PL1: 55W (vs 110W stock)
- Speed Shift Max: 40 (4.0GHz boost)
- Fans: curvas agressivas (100% @ 80°C)
- GPU: perfil undervolt (775mV)

### Silent Mode
- Undervolt CPU: -80mV core, -70mV cache
- PL1: 25W
- Speed Shift Max: 28 (2.8GHz max)
- Fans: curvas silenciosas
- GPU: perfil undervolt (725mV)

## Setup inicial

1. Configure o Throttlestop manualmente uma vez para gerar o Throttlestop.ini
2. Configure os perfis do MSI Afterburner (veja profiles/afterburner/README.md)
3. Instale o NBFC e teste com os JSONs fornecidos
4. Edite install-paths.ps1 com os caminhos corretos
5. Execute toggle-mode.ps1

## Temperaturas esperadas

| Cenário | Stock | Gaming Mode |
|---------|-------|-------------|
| Navegação | 50-60°C | 45-55°C |
| Jogo leve | 80-88°C | 65-75°C |
| Jogo pesado | 92-97°C | 72-82°C |
