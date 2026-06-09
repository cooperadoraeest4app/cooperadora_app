# Cooperadora App — Documento de Contexto del Proyecto

> Versión 2.0 — Diseño de base de datos completo incluyendo sistema de votaciones y tipos de socios.
> Reinsertá este archivo al inicio de cada sesión de trabajo con IA.

---

## 1. Descripción General

Aplicación de gestión de **Ingresos y Gastos** para Cooperadoras escolares.
- Código abierto en GitHub — cada Cooperadora tiene su propia instancia Firebase
- Multi-usuario con roles diferenciados
- Secciones públicas configurables para transparencia comunitaria
- Sistema democrático de votaciones integrado

---

## 2. Stack Tecnológico

| Componente | Tecnología |
|---|---|
| App móvil (Android) + Web | Flutter |
| Base de datos | Firebase Firestore |
| Autenticación | Firebase Auth |
| Almacenamiento | Firebase Storage |
| Repositorio | GitHub (público) |
| IDE | VS Code + Claude Code |

---

## 3. Entorno de Desarrollo

- **SO:** Windows 11 (25H2) — Flutter 3.44.0
- **Flutter SDK:** `C:\dev\flutter\flutter`
- **Android SDK:** `C:\dev\AndroidSDK`
- **Proyecto:** `C:\dev\proyectos\cooperadora_app`
- **GitHub:** `https://github.com/cooperadoraeest4app/cooperadora_app`
- **Branch:** `main` — sin OneDrive, versionado solo con Git

---

## 4. Permisos por Rol

| Acción | Público | Solo lectura | Editor | Admin |
|---|---|---|---|---|
| Ver secciones públicas | ✓ | ✓ | ✓ | ✓ |
| Ver secciones privadas | — | ✓ | ✓ | ✓ |
| Cargar ingresos/gastos | — | — | ✓ | ✓ |
| Editar ingresos/gastos | — | — | ✓ | ✓ |
| Cargar socios/cuotas | — | — | ✓ | ✓ |
| Gestionar proyectos | — | — | ✓ | ✓ |
| Gestionar categorías | — | — | — | ✓ |
| Gestionar cargos | — | — | — | ✓ |
| Gestionar usuarios | — | — | — | ✓ |
| Configuración general | — | — | — | ✓ |
| Activar visibilidad pública | — | — | — | ✓ |
| Ver LogAcceso | — | — | — | ✓ |

---

## 5. Entidades — Versión 2.0 Completa

### Persona
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `apellido` | string | |
| `dni` | string | Identificador único |
| `telefono` | string | |
| `email` | string | Opcional |
| `fechaNacimiento` | timestamp | Opcional |
| `direccion` | string | Opcional. Abre Google Maps |
| `fotoUrl` | string | Opcional. URL Firebase Storage |
| `cargoId` | string | Opcional. Cargo institucional |
| `habilidades` | array\<string\> | Tags de oficios. Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

### Cargo
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Presidente, Secretaria, Tesorera, Vocal 1, Vocal 2, Vocal 3, Vocal 1 Suplente, Vocal 2 Suplente, Revisora de Cuenta, Profesora Revisora de Cuenta, Revisora de Cuenta Suplente.

### Usuario
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `personaId` | string | |
| `rol` | string | `admin` / `editor` / `solo_lectura` / `estudiante` (pendiente) |
| `socioId` | string | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

> Último acceso se consulta dinámicamente desde LogAcceso.
> Miembros de comisión directiva = Usuarios cuya Persona tiene `cargoId` asignado.

### Log de Acceso
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `usuarioId` | string | |
| `fecha` | timestamp | |
| `dispositivo` | string | Opcional |
| `accion` | string | `login` / `logout` / `sesion_expirada` |

> Sin IP por Ley 25.326 de Protección de Datos Personales.

### Método de Pago
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Efectivo, Transferencia bancaria, Débito, Crédito, Cheque.

### Categoría
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `tipo` | string | `ingreso` / `gasto` |
| `descripcion` | string | Opcional |
| `icono` | string | Material Icons |
| `color` | string | Hex |
| `activa` | boolean | |

**Ingresos:** Cuota de socios, Donación, Subsidio, Evento, Venta, Otros ingresos.
**Gastos:** Servicios, Materiales escolares, Equipamiento, Mantenimiento, Honorarios, Eventos, Otros gastos.

### Frecuencia de Recurrencia
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `diasIntervalo` | number | Ej: 7, 15, 30 |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Semanal (7), Quincenal (15), Mensual (30), Bimestral (60), Trimestral (90), Anual (365).

### Ingreso
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `monto` | number | |
| `moneda` | string | Por defecto `"ARS"`. Oculto en interfaz |
| `fecha` | timestamp | |
| `descripcion` | string | Opcional |
| `metodoPagoId` | string | |
| `donante` | string | Opcional. Donante externo |
| `donanteEmail` | string | Opcional |
| `donanteTelefono` | string | Opcional |
| `donanteUsuarioId` | string | Opcional. Donante miembro |
| `categoriaId` | string | Solo tipo ingreso |
| `proyectoId` | string | Opcional |
| `itemProyectoId` | string | Opcional |
| `recurrente` | boolean | |
| `frecuenciaId` | string | Opcional |
| `proximaFecha` | timestamp | Opcional. Calculada automáticamente |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Gasto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `monto` | number | |
| `moneda` | string | Por defecto `"ARS"`. Oculto en interfaz |
| `fecha` | timestamp | |
| `descripcion` | string | Opcional |
| `metodoPagoId` | string | |
| `categoriaId` | string | Solo tipo gasto |
| `proyectoId` | string | Opcional |
| `itemProyectoId` | string | Opcional |
| `recurrente` | boolean | |
| `frecuenciaId` | string | Opcional |
| `proximaFecha` | timestamp | Opcional. Calculada automáticamente |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Tipo de Socio
Basado en Decreto 4767/72 Art. 40°.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | Activo, Honorario, Adherente, Consultante |
| `tieneVoto` | boolean | Solo Activo = true |
| `tieneVozConsultiva` | boolean | Adherente y Consultante = true |
| `requiereCuota` | boolean | Activo y Adherente = true |
| `orden` | number | |
| `activo` | boolean | |

### Subtipo de Socio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `aplicaA` | array\<string\> | Lista de tipoSocioId |
| `orden` | number | |
| `activo` | boolean | |

**Activo, Adherente, Consultante:** Padre, Madre, Familiar, Docente, Auxiliar, No docente, Directivo, Alumno, Ex-alumno, Otro.
**Honorario:** Empresa, Persona física, Organización, Otro.

### Socio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `tipoSocioId` | string | |
| `subtipoSocioId` | string | |
| `apellidoFamilia` | string | Para Activos, Adherentes y Consultantes |
| `razonSocial` | string | Solo Honorarios empresas/organizaciones |
| `cuit` | string | Solo Honorarios empresas/organizaciones |
| `personaContactoId` | string | Para Honorarios: el delegado |
| `activo` | boolean | |
| `fechaIngreso` | timestamp | |
| `observaciones` | string | Opcional |

### Integrante
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `personaId` | string | |
| `socioId` | string | |
| `tipo` | string | `padre` / `madre` / `tutor` / `alumno` |
| `grado` | string | Solo si alumno. Opcional |

### Tipo de Cuota
**Por defecto:** Mensual, Anual.

### Tarifa de Cuota
Historial de valores por tipo. Nuevo registro al actualizar precio.

### Cuota
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `socioId` | string | |
| `tipoCuotaId` | string | |
| `tarifaId` | string | |
| `periodo` | string | MM/YYYY |
| `monto` | number | Monto efectivamente pagado |
| `metodoPagoId` | string | |
| `fechaPago` | timestamp | |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `observaciones` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Tipo de Proyecto
**Por defecto:** Evento, Infraestructura, Viaje de Estudios, Equipamiento, Otros.
> Evento fue absorbido por Proyecto via este campo.

### Proyecto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `descripcion` | string | Opcional |
| `tipoProyectoId` | string | |
| `presupuestoActual` | number | Se recalcula al modificar ítems |
| `fechaInicio` | timestamp | |
| `fechaFinEstimada` | timestamp | Opcional |
| `fechaFinReal` | timestamp | Opcional |
| `estado` | string | `planificado` / `en_curso` / `finalizado` |
| `responsables` | array\<string\> | |
| `publico` | boolean | Por defecto true |
| `votacionId` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Revisión de Presupuesto
Historial de cambios de presupuesto. Nuevo registro al modificar.

### Proveedor
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `contacto` | string | Opcional |
| `telefono` | string | Opcional |
| `email` | string | Opcional |
| `cuit` | string | Opcional |
| `direccion` | string | Opcional |
| `web` | string | Opcional |
| `rubro` | string | Opcional |
| `confianza` | boolean | |
| `observaciones` | string | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

### Item de Proyecto
Flujo: `pendiente` → `en_gestion` → `presupuestos_aprobados` → `comprado`

### Presupuesto de Proveedor
Máximo 3 por ítem. Solo uno puede estar aprobado.

### Votación
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `titulo` | string | |
| `descripcion` | string | Opcional |
| `entidadTipo` | string | `proyecto` / `presupuesto_proveedor` / `otro` |
| `entidadId` | string | |
| `estado` | string | `abierta` / `cerrada` / `aprobada` / `rechazada` |
| `modalidad` | string | `digital` / `presencial` / `mixta` |
| `fechaInicio` | timestamp | |
| `fechaFin` | timestamp | Mismo día para presencial |
| `porcentajeAprobacion` | number | Por defecto desde Configuración |
| `quorumMinimo` | number | Por defecto desde Configuración |
| `participantes` | array\<string\> | socioId que votaron |
| `votosAfavor` | number | Solo socios Activos |
| `votosEnContra` | number | Solo socios Activos |
| `abstenciones` | number | Solo socios Activos |
| `votosConsultivosAfavor` | number | Adherentes y Consultantes |
| `votosConsultivosEnContra` | number | Adherentes y Consultantes |
| `forzadoPorAdmin` | boolean | |
| `usuarioId` | string | |
| `fechaCreacion` | timestamp | |

### Voto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `votacionId` | string | |
| `valor` | string | `afirmativo` / `negativo` / `abstencion` |
| `tipoSocioId` | string | Se desprende del tipo de socio del votante |
| `modalidad` | string | `digital` / `presencial` |
| `fechaCreacion` | timestamp | |

> **SocioId NO se guarda** para preservar secreto del voto. Participación en array `participantes` de Votación.

### Configuración
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Fijo: `"config"` |
| `nombreCooperadora` | string | |
| `nombreEscuela` | string | |
| `direccionEscuela` | string | Opcional |
| `telefonoContacto` | string | Opcional |
| `emailContacto` | string | Opcional |
| `logoUrl` | string | Opcional |
| `seccionesPublicas` | map | |
| `monedaDefault` | string | ARS |
| `añoLectivoActivo` | number | |
| `quorumMinimoDefault` | number | % socios activos requerido |
| `porcentajeAprobacionDefault` | number | % votos afirmativos requerido |
| `fechaActualizacion` | timestamp | |
| `usuarioId` | string | |

---

## 6. Pendientes

- **Rol Estudiante:** definir acceso y autenticación
- **Ideas futuras:** módulo pasantías, Socio Vitalicio

---

## 7. Orden de Desarrollo

1. Configurar Firebase
2. Estructura base Flutter
3. Módulo Configuración
4. Módulo Ingresos y Gastos
5. Módulo Categorías y Métodos de Pago
6. Módulo Socios y Cuotas
7. Módulo Proyectos
8. Gráficos y reportes
9. Módulo Votaciones

---

## 8. Decisiones Clave

- Firestore: sin migraciones, campos agregables en cualquier momento
- Persona como base: sin duplicación de datos personales
- Voto secreto: socioId no en Voto, participación en array de Votación
- Una instancia Firebase por Cooperadora
- Sin IP en logs por Ley 25.326
- Evento absorbido por Proyecto via TipoProyecto
- Gastos/Ingresos recurrentes via FrecuenciaRecurrencia
- Tipos de socio basados en Decreto 4767/72 Art. 40° + Consultante propio

---

## 9. Pendientes Técnicos

- **Firebase Storage pendiente de configurar:** requiere plan Blaze con cuenta de facturación. Postponido hasta el módulo de comprobantes. Configurar en console.firebase.google.com → Storage → southamerica-east1.

---

*v2.0 — Base de datos completa. Próximo paso: configurar Firebase.*

### 5.1 CuentaBancaria *(definida)*

Documento único en Firestore con id fijo `"cuenta_principal"`. A futuro escalable a múltiples cuentas agregando ids dinámicos y `cuentaId` en MovimientoBancario.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Fijo: `"cuenta_principal"` |
| `banco` | string | Ej: "Banco Nación" |
| `tipoCuenta` | string | "Caja de ahorro" / "Cuenta corriente" |
| `cbu` | string | |
| `alias` | string | Opcional |
| `saldoActual` | number | Se actualiza con cada MovimientoBancario |
| `moneda` | string | Por defecto ARS |
| `activa` | boolean | |
| `fechaActualizacion` | timestamp | |

### 5.2 MovimientoBancario *(definido)*

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `tipo` | string | `actualizacion_saldo` / `resumen_mensual` |
| `saldoAnterior` | number | |
| `saldoNuevo` | number | Solo para `actualizacion_saldo` |
| `periodo` | string | MM/YYYY. Solo para `resumen_mensual` |
| `archivo` | string | URL Firebase Storage. PDF del resumen |
| `observaciones` | string | Opcional |
| `usuarioId` | string | Quién cargó el movimiento |
| `fechaCreacion` | timestamp | |

**Permisos:**
- Ver saldo y descargar resúmenes: público (sujeto a `seccionesPublicas.resumenBancario`)
- Actualizar saldo y subir resúmenes: solo Admin

### Actualización: Configuración
Se agrega `resumenBancario: true` al map `seccionesPublicas`. Por defecto público, configurable por Admin.

---

*Última actualización: CuentaBancaria y MovimientoBancario definidos. Módulo de Ingresos y Gastos conectado a Firestore y funcionando.*

---

### 5.3 Invitacion *(definida)*

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `codigo` | string | Código único alfanumérico generado automáticamente |
| `tipo` | string | `individual` / `generica` |
| `rolAsignado` | string | Rol fijo. El usuario NO puede cambiarlo al registrarse |
| `nombreDestino` | string | Opcional. Precargado por el Admin |
| `apellidoDestino` | string | Opcional |
| `telefonoDestino` | string | Opcional |
| `emailDestino` | string | Solo para invitación individual |
| `usada` | boolean | Para invitaciones individuales |
| `usos` | number | Para invitaciones genéricas, cuenta registros |
| `limiteUsos` | number | Opcional. Límite de usos para invitación genérica |
| `fechaVencimiento` | timestamp | Opcional |
| `creadaPor` | string | usuarioId del Admin |
| `fechaCreacion` | timestamp | |

**Flujo invitación individual:**
1. Admin crea invitación con datos del destinatario y rol asignado
2. Sistema genera link único con código
3. Admin envía link por WhatsApp o email
4. Usuario abre link, ve datos precargados, solo ingresa contraseña
5. Se crea Usuario con rol fijo de la invitación

**Flujo invitación genérica (cartelera):**
1. Admin genera link genérico para consultantes
2. Se publica en cartelera de la escuela
3. Alumno/docente abre link, completa nombre, apellido, email y contraseña
4. Queda registrado automáticamente como `consultante`

---

## 10. Pendientes de Implementación

### Alta prioridad
- [ ] Pantalla de registro de usuario con sistema de invitaciones
- [ ] Panel de administración (gestión de usuarios, roles, invitaciones)
- [ ] Control de visibilidad por rol en toda la app (actualmente solo por login)
- [ ] Módulo Cuenta Bancaria (saldo, resúmenes mensuales PDF)

### Media prioridad
- [ ] Login por biometría (huella dactilar) en Android
- [ ] Login por teléfono con SMS
- [ ] Firebase Dynamic Links para links de invitación
- [ ] Módulo Socios y Cuotas
- [ ] Módulo Proyectos
- [ ] Gráficos y reportes

### Baja prioridad / A futuro
- [ ] Sistema de Votaciones
- [ ] Módulo de habilidades (directorio de oficios)
- [ ] Notificaciones push para gastos recurrentes
- [ ] Inventario básico

---

*Última actualización: Autenticación Firebase Auth implementada. Sistema de invitaciones definido. FAB visible solo con login.*

---

## 11. Estado de Implementación

### Completado ✅
- Entorno de desarrollo: Flutter 3.44.0, Android Studio, VS Code, Claude Code
- Firebase: Firestore, Authentication (email/contraseña), Storage (pendiente de uso)
- Arquitectura feature-first con Provider para estado
- Tema visual: paleta celeste/azul oscuro/verde teal
- Módulo Ingresos y Gastos: modelos, repositorios, formulario, listado conectado a Firestore
- Autenticación: login, logout, registro con código de invitación
- Control de roles: `esAdmin`, `esEditor`, `esSoloLectura`, `esConsultante` en AuthProvider
- Panel de administración: Configuración, Usuarios, Invitaciones
- FAB visible solo con login y permisos

### Detalles técnicos importantes
- Campo `authUid` en documentos de `usuarios` vincula Firebase Auth UID con Firestore
- Al registrarse se crean 3 documentos: Auth user + Persona + Usuario en Firestore
- El Admin en Firestore debe tener `authUid` igual al UID de Firebase Auth
- Categorías hardcodeadas en `lib/shared/data/categorias_data.dart` — pendiente migrar a Firestore
- Métodos de pago hardcodeados en formulario — pendiente migrar a Firestore

### Pendiente inmediato
- [ ] Categorías y Métodos de pago gestionables desde panel admin
- [ ] Migrar categorías hardcodeadas a Firestore
- [ ] Módulo Cuenta Bancaria
- [ ] Pantalla pública sin login con secciones configurables

### Estructura de colecciones Firestore
- `ingresos` — movimientos de ingreso
- `gastos` — movimientos de gasto
- `usuarios` — usuarios con rol y authUid
- `personas` — datos personales
- `configuracion` — documento único id: "config"
- `invitaciones` — invitaciones de registro
- `categorias` — pendiente de poblar
- `metodos_pago` — pendiente de poblar

---

*Última actualización: Control de roles implementado. Panel admin con Configuración, Usuarios e Invitaciones funcionando.*

### Donación en Especie *(idea futura)*

Entidad para registrar donaciones no monetarias (bienes, materiales, equipamiento).

**DonacionEspecie**
- `id` string
- `descripcion` string — Ej: "Parrilla", "Materiales escolares"
- `valorEstimado` number — Opcional
- `donante` string — Opcional. Nombre si es externo
- `donanteUsuarioId` string — Opcional. Si es miembro
- `fecha` timestamp
- `estado` string — `recibido` / `en_uso` / `dado_de_baja`
- `foto` string — URL Firebase Storage. Opcional
- `observaciones` string — Opcional
- `fechaCreacion` timestamp

> Conecta a futuro con el módulo de inventario y el directorio de habilidades.

---

### Historial Cuenta Bancaria — Especificación UI

**Vista por defecto:**
- Últimas 6 entradas mezcladas (actualizaciones de saldo + resúmenes mensuales)
- Ordenadas descendente por fecha
- Botón de ordenamiento asc/desc

**Filtro "Solo resúmenes mensuales":**
- Toggle que activa el modo resúmenes
- Dropdown de año disponible
- Muestra los 12 meses del año seleccionado
- Meses con resumen: muestran ícono de descarga del PDF
- Meses sin resumen: chip "Pendiente"
- Mutuamente excluyente con filtro por fecha

**Filtro por fecha:**
- Selector "Desde" y "Hasta"
- Lista de máximo 12 entradas por página con paginado
- Botón ordenamiento ascendente/descendente
- Mutuamente excluyente con filtro de resúmenes

**Extras:**
- Botón "Limpiar filtros" vuelve a vista por defecto
- Versión pública de solo lectura accesible desde pantalla principal
- En versión pública: saldo actual + historial + resúmenes descargables
- Sin opciones de edición para usuarios sin rol Admin

*Confirmado para implementar junto con el módulo bancario completo.*

---

### Actualización: Módulo Cuenta Bancaria — Flujo unificado

**Actualizar saldo + Resumen mensual en un solo paso:**

Al actualizar el saldo el Admin puede opcionalmente adjuntar el resumen bancario PDF en el mismo formulario.

- Si adjunta PDF → se guarda `MovimientoBancario` con `tipo: 'resumen_mensual'`, `periodo: MM/YYYY` y `archivo: URL`
- Si no adjunta → se guarda `tipo: 'actualizacion_saldo'` normal

En el historial los registros con resumen adjunto muestran ícono de PDF descargable. Los sin resumen muestran solo la actualización de saldo.

El botón "Subir resumen mensual" separado se elimina, queda todo unificado en "Actualizar saldo".

