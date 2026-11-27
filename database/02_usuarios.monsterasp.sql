/* Ejecutar en db83114 después de 01_restaurante.monsterasp.sql. */
CREATE TABLE dbo.Usuarios
(
    UsuarioId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuarios PRIMARY KEY,
    Correo NVARCHAR(150) NOT NULL,
    ClaveHash NVARCHAR(100) NOT NULL,
    Rol NVARCHAR(30) NOT NULL CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN (N'Chef', N'Mesero'))
);
GO
CREATE UNIQUE INDEX UX_Usuarios_Correo ON dbo.Usuarios (Correo);
GO
INSERT INTO dbo.Usuarios (Correo, ClaveHash, Rol) VALUES
(N'chef@restaurante.com', N'$2a$11$zcAhJCgWPRav7iNK7THqzOdUfgtOkvKL1sXuiSMhRG3M4.s2dQR7m', N'Chef'),
(N'mesero@restaurante.com', N'$2a$11$1IJ2E7xWKex6RuI.VkG91exeXemAPo4yTl5mP7nzl9WrAHMC3Oexm', N'Mesero');
GO
