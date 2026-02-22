# 📘 Proyecto MATLAB — Guía para unirse al repositorio

Este documento explica los pasos que debe seguir cualquier miembro del equipo para conectarse al proyecto y trabajar correctamente usando MATLAB Online y GitHub.

---

## 🔧 Requisitos previos

Antes de empezar, asegúrate de tener:

* ✅ Cuenta de GitHub
* ✅ Acceso a MATLAB Online (cuenta de la universidad)
* ✅ Invitación aceptada al repositorio de GitHub

> ⚠️ Importante: Debes aceptar la invitación en GitHub antes de continuar.

---

## 🚀 Paso 1 — Clonar el repositorio en MATLAB Online

1. Abre **MATLAB Online**
2. Ve a **Home → Clone**
3. Pega la URL del repositorio:

```
https://github.com/USUARIO/REPOSITORIO.git
```

4. Pulsa **Clone**

MATLAB descargará el proyecto a tu MATLAB Drive.

---

## 📂 Paso 2 — Abrir el proyecto

1. En el panel **Files**, entra en la carpeta descargada
2. Haz doble clic en el archivo **.prj**

✅ Esto activa correctamente el entorno del proyecto.

---

## 🔑 Paso 3 — Crear tu token de GitHub (solo la primera vez)

GitHub no permite usar contraseña. Necesitas un **Personal Access Token**.

### Crear el token

1. En GitHub: **Settings → Developer settings**
2. **Personal access tokens → Tokens (classic)**
3. **Generate new token (classic)**
4. Configura:

* Note: `matlab-online`
* Expiration: la que prefieras
* Permisos: ✅ `repo`

5. Pulsa **Generate token**
6. **Copia el token** (solo se muestra una vez)

---

## 🔐 Paso 4 — Autenticación en MATLAB

Cuando MATLAB pida credenciales:

* **Username:** tu usuario de GitHub
* **Password:** pega el **token** (NO tu contraseña)

---

## 🔄 Flujo de trabajo obligatorio del equipo

Para evitar conflictos, TODOS deben seguir este orden.

### 🟢 Antes de empezar a trabajar

```
Pull
```

Esto descarga los últimos cambios del equipo.

---

### ✏️ Mientras trabajas

* Edita los archivos necesarios
* Evita que dos personas editen el mismo archivo a la vez
* Coordinaos por WhatsApp/Discord

---

### 💾 Al terminar

1. **Commit** (con mensaje descriptivo)
2. **Push**

Esto sube tus cambios al repositorio.

---

### 👤 Si vas después de otro compañero

Siempre:

```
Pull → trabajar → Commit → Push
```

---

## ⚠️ Normas importantes del proyecto

* ❌ No trabajar sin hacer Pull antes
* ❌ No subir archivos innecesarios o muy pesados
* ❌ No editar el mismo archivo simultáneamente sin avisar
* ✅ Usar mensajes de commit claros
* ✅ Avisar al equipo cuando hagas push importante

---

## 🧪 Comprobación rápida

Todo está bien si:

* Puedes hacer **Pull** sin errores
* Puedes hacer **Push**
* Tus commits aparecen en GitHub

---

## 🆘 Problemas comunes

**Authentication failed**
→ Estás usando contraseña en vez de token.

**Permission denied**
→ No has aceptado la invitación al repo.

**Repository not found**
→ URL mal copiada o repo privado sin acceso.

---

## 👥 Contacto del equipo

Si tienes problemas, avisa en el canal del equipo antes de forzar cambios en Git.

---

**Fin de la guía**
