# MSI Afterburner — Perfis de Undervolt para RTX 3070 Max-Q

## Perfil 2 — Gaming (Undervolt)

1. Abra o MSI Afterburner
2. Pressione Ctrl+F para abrir o Curve Editor
3. Encontre o ponto em 775mV no eixo X
4. Pressione L para travar (Lock)
5. Arraste o ponto para cima até a frequência que sua GPU já atinge em stock (~1500-1550MHz)
6. Clique em Apply (checkmark)
7. Vá em Profiles > Save > 2 (slot 2)

## Perfil 3 — Silent (Undervolt + Clock baixo)

1. Mesmo processo, mas trave em 725mV e arraste para ~1200-1300MHz
2. Salve no slot 3

## Verificar se o CLI funciona

```powershell
& "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" /Profile2
```

## Notas
- Perfil 1 = stock (sem undervolt)
- Perfil 2 = gaming (775mV @ stock freq)
- Perfil 3 = silent (725mV @ 1200-1300MHz)
