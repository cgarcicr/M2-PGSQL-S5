-- Taller nro 5 consultas avanzadas, CAMILO ANDRES GARCIA CRUZ
--Crea una nueva cuenta bancaria para un cliente, asignando un número de cuenta único y estableciendo un saldo inicial.
CREATE OR REPLACE PROCEDURE crear_cuenta_bancaria(
    p_cliente_id INTEGER,
    p_tipo_cuenta VARCHAR(10),
    p_saldo_inicial NUMERIC(10, 2),
    p_estado VARCHAR(10),
    OUT v_cuenta_id INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_numero_cuenta VARCHAR(20);
BEGIN
    -- Generar un número de cuenta único
    v_numero_cuenta := 'CUENTA-' || nextval('cuentasbancarias_cuenta_id_seq');

    -- Insertar la nueva cuenta bancaria
    INSERT INTO cuentasbancarias (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado)
    VALUES (p_cliente_id, v_numero_cuenta, p_tipo_cuenta, p_saldo_inicial, CURRENT_DATE, p_estado)
    RETURNING cuenta_id INTO v_cuenta_id;
END;
$$;

CALL crear_cuenta_bancaria(1, 'ahorro', 1000.00, 'activa', NULL);


--Actualiza la información personal de un cliente, como dirección, teléfono y correo electrónico, basado en el ID del cliente
CREATE OR REPLACE PROCEDURE actualizar_informacion_cliente(
    p_cliente_id INTEGER,
    p_direccion VARCHAR(255),
    p_telefono VARCHAR(20),
    p_correo_electronico VARCHAR(100)
) LANGUAGE plpgsql AS $$
BEGIN
    -- Actualizar la información del cliente
    UPDATE clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo_electronico
    WHERE cliente_id = p_cliente_id;
END;
$$;

CALL actualizar_informacion_cliente(1, 'Nueva Dirección', '1234567890', 'nuevoemail@example.com');


--Eliminar una cuenta bancaria específica del sistema, incluyendo la eliminación de todas las transacciones asociadas.
CREATE OR REPLACE PROCEDURE eliminar_cuenta_bancaria(
    p_cuenta_id INTEGER
) LANGUAGE plpgsql AS $$
BEGIN
    -- Eliminar todas las transacciones asociadas a la cuenta bancaria
    DELETE FROM transacciones
    WHERE cuenta_id = p_cuenta_id;

    -- Eliminar todas las tarjetas de crédito asociadas a la cuenta bancaria
    DELETE FROM tarjetascredito
    WHERE cuenta_id = p_cuenta_id;

    -- Eliminar todos los préstamos asociados a la cuenta bancaria
    DELETE FROM prestamos
    WHERE cuenta_id = p_cuenta_id;

    -- Eliminar la cuenta bancaria específica
    DELETE FROM cuentasbancarias
    WHERE cuenta_id = p_cuenta_id;
END;
$$;

CALL eliminar_cuenta_bancaria(1);


--Realiza una transferencia de fondos desde una cuenta a otra, asegurando que ambas cuentas se actualicen correctamente y se registre la transacción.
CREATE OR REPLACE PROCEDURE transferir_fondos(
    p_cuenta_origen_id INTEGER,
    p_cuenta_destino_id INTEGER,
    p_monto NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    -- Verificar que ambas cuentas existen
    IF NOT EXISTS (SELECT 1 FROM cuentasbancarias WHERE cuenta_id = p_cuenta_origen_id) THEN
        RAISE EXCEPTION 'La cuenta de origen no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cuentasbancarias WHERE cuenta_id = p_cuenta_destino_id) THEN
        RAISE EXCEPTION 'La cuenta de destino no existe';
    END IF;

    -- Verificar que la cuenta de origen tiene fondos suficientes
    IF (SELECT saldo FROM cuentasbancarias WHERE cuenta_id = p_cuenta_origen_id) < p_monto THEN
        RAISE EXCEPTION 'Fondos insuficientes en la cuenta de origen';
    END IF;

    -- Actualizar el saldo de la cuenta de origen
    UPDATE cuentasbancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = p_cuenta_origen_id;

    -- Actualizar el saldo de la cuenta de destino
    UPDATE cuentasbancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = p_cuenta_destino_id;

    -- Registrar la transacción
    INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion)
    VALUES (p_cuenta_origen_id, 'transferencia', p_monto, NOW()::date),
           (p_cuenta_destino_id, 'transferencia', p_monto, NOW()::date);
END;
$$;

CALL transferir_fondos(2, 2, 100.00);


--Registra una nueva transacción (depósito, retiro) en el sistema, actualizando el saldo de la cuenta asociada.
CREATE OR REPLACE PROCEDURE registrar_transaccion(
    p_cuenta_id INTEGER,
    p_tipo_transaccion VARCHAR(15),
    p_monto NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    -- Verificar que la cuenta existe
    IF NOT EXISTS (SELECT 1 FROM cuentasbancarias WHERE cuenta_id = p_cuenta_id) THEN
        RAISE EXCEPTION 'La cuenta no existe';
    END IF;

    -- Actualizar el saldo de la cuenta basado en el tipo de transacción
    IF p_tipo_transaccion = 'depósito' THEN
        UPDATE cuentasbancarias
        SET saldo = saldo + p_monto
        WHERE cuenta_id = p_cuenta_id;
    ELSIF p_tipo_transaccion = 'retiro' THEN
        -- Verificar que la cuenta tiene fondos suficientes para el retiro
        IF (SELECT saldo FROM cuentasbancarias WHERE cuenta_id = p_cuenta_id) < p_monto THEN
            RAISE EXCEPTION 'Fondos insuficientes en la cuenta';
        END IF;
        UPDATE cuentasbancarias
        SET saldo = saldo - p_monto
        WHERE cuenta_id = p_cuenta_id;
    ELSE
        RAISE EXCEPTION 'Tipo de transacción no válido';
    END IF;

    -- Registrar la transacción
    INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion)
    VALUES (p_cuenta_id, p_tipo_transaccion, p_monto, NOW()::date);
END;
$$;

CALL registrar_transaccion(2, 'depósito', 100.00);
CALL registrar_transaccion(2, 'retiro', 50.00);


--Calcula el saldo total combinado de todas las cuentas bancarias pertenecientes a un cliente específico.
CREATE OR REPLACE PROCEDURE calcular_saldo_total_cliente(
    p_cliente_id INTEGER,
    OUT p_saldo_total NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    -- Verificar que el cliente existe
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE cliente_id = p_cliente_id) THEN
        RAISE EXCEPTION 'El cliente no existe';
    END IF;

    -- Calcular el saldo total combinado de todas las cuentas del cliente
    SELECT COALESCE(SUM(saldo), 0) INTO p_saldo_total
    FROM cuentasbancarias
    WHERE cliente_id = p_cliente_id;
END;
$$;

DO $$
DECLARE
    saldo_total NUMERIC;
BEGIN
    CALL calcular_saldo_total_cliente(1, saldo_total);
    RAISE NOTICE 'Saldo total: %', saldo_total;
END;
$$;


--Genera un reporte detallado de todas las transacciones realizadas en un rango de fechas específico.
CREATE OR REPLACE PROCEDURE generar_reporte_transacciones(
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    OUT refcursor refcursor
) LANGUAGE plpgsql AS $$
BEGIN
    -- Verificar que las fechas son válidas
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser mayor que la fecha de fin';
    END IF;

    -- Abrir el cursor para seleccionar todas las transacciones en el rango de fechas especificado
    OPEN refcursor FOR
    SELECT transaccion_id, cuenta_id, tipo_transaccion, monto, fecha_transaccion
    FROM transacciones
    WHERE fecha_transaccion BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY fecha_transaccion;
END;
$$;


DO $$
DECLARE
    refcursor refcursor;
    transaccion RECORD;
BEGIN
    CALL generar_reporte_transacciones('2023-01-01', '2023-12-31', refcursor);
    LOOP
        FETCH NEXT FROM refcursor INTO transaccion;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Transacción ID: %, Cuenta ID: %, Tipo: %, Monto: %, Fecha: %',
            transaccion.transaccion_id,
            transaccion.cuenta_id,
            transaccion.tipo_transaccion,
            transaccion.monto,
            transaccion.fecha_transaccion;
    END LOOP;
    CLOSE refcursor;
END;
$$;