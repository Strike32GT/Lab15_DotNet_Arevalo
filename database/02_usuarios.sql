/* ============================================================
   Base de datos: RestauranteDB
   Script incremental: tabla Usuarios y usuarios de prueba
   Motor: SQL Server
   Ejecutar después de 01_restaurante.sql
   ============================================================ */

USE RestauranteDB;
GO

/* ------------------------------------------------------------
   Tabla Usuarios
   Correo único, clave cifrada con BCrypt y rol del negocio.
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios
    (
        UsuarioId INT IDENTITY(1,1) NOT NULL,
        Correo    NVARCHAR(150) NOT NULL,
        ClaveHash NVARCHAR(100) NOT NULL,
        Rol       NVARCHAR(30)  NOT NULL,
        CONSTRAINT PK_Usuarios PRIMARY KEY (UsuarioId),
        CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN (N'Chef', N'Mesero'))
    );
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'UX_Usuarios_Correo'
      AND object_id = OBJECT_ID('dbo.Usuarios')
)
BEGIN
    CREATE UNIQUE INDEX UX_Usuarios_Correo ON dbo.Usuarios (Correo);
END
GO

/* ------------------------------------------------------------
   Usuarios de prueba, uno por cada rol.
   Claves de prueba:
     chef@restaurante.com   -> Chef123!
     mesero@restaurante.com -> Mesero123!
   El hash se generó con BCrypt y nunca se guarda la clave en texto.
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'chef@restaurante.com')
BEGIN
    INSERT INTO dbo.Usuarios (Correo, ClaveHash, Rol)
    VALUES
    (
        N'chef@restaurante.com',
        N'$2a$11$zcAhJCgWPRav7iNK7THqzOdUfgtOkvKL1sXuiSMhRG3M4.s2dQR7m',
        N'Chef'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = N'mesero@restaurante.com')
BEGIN
    INSERT INTO dbo.Usuarios (Correo, ClaveHash, Rol)
    VALUES
    (
        N'mesero@restaurante.com',
        N'$2a$11$1IJ2E7xWKex6RuI.VkG91exeXemAPo4yTl5mP7nzl9WrAHMC3Oexm',
        N'Mesero'
    );
END
GO

SELECT UsuarioId, Correo, Rol FROM dbo.Usuarios;
GO
