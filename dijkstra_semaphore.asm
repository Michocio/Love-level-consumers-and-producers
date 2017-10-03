; Michał Jaroń
; mj348711

global proberen, verhogen


proberen:	;rdi to parametr funkcji, a więc referancja do semafora
	xor eax, eax	; Wyzeruj edx
	petla :
		; jeżeli to nie pierwszy obieg to eax = 1, jeśli pierwszy to eax = 0
		lock xadd dword [rdi], eax	; semafor = semafor +/- ? (przywróć wartość)
		
		mov dword eax, -1;0xFFFFFFFFFFFFFFFF	;eax = -1
		lock xadd dword [rdi], eax	; semafor = semafor -1
					
		cmp dword eax, 0x0; Czy mniejsze od 0?
			jg koniec		; skok, jeśli większe (ze znakiem)
		
		; mniejsze równe 0
		mov dword eax, 0x1	; przygotowanie wartości do przywrócenia [rdi]
		jmp petla			; kolejny obrót
	koniec: ret

	
verhogen:; rdi to parametr funkcji, a więc referencja do semafora
	lock add dword [rdi], 0x1	; Atomowe dodaj 1
	ret  
