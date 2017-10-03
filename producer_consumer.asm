; Michał Jaroń
; mj348711

global init, zwroc, producer, consumer


; Funkcje z innych jednostek kompilacji
extern malloc
extern produce
extern consume
extern proberen
extern verhogen

; Sekcja zmiennych statycznych
SECTION .bss
  rozmiar: 	resd 1	; Double word - 32 bity
  bufor: 	resq 1	; Quad word - 64bity
  wolne:	resd 1	; Double word - 32 bity
  zajete:	resd 1  ; Double word - 32 bity
  porcja: 	resq 1	; Quad word - 64bity
  porownaj: resd 1	; Double word - 32 bity, pomocnicza do przenoszenia
  pamietaj: resq 1	; Quad word - 64bity

section .text
; Początek kodu programu


; int init(size_t N);
init:
	; edi <- size_t N, a więc liczba bez znaku
	
	cmp edi, 0x7FFFFFFF; 2147483647
	ja problem_bound_val; N > 2^{31} - 1; ja == bez znaku
	
	test edi, edi; Jeśli równe 0
	jz problem_zero_val; jz <- skok, jeśli edi == zero
	
	; Inicjalizacja semaforów i zmiennych pomocniczych
	mov[rozmiar], edi
	mov [wolne], edi
	mov dword [zajete], 0x0
	
	
	imul edi, 8; Powiedz ile malloc ma zaalokować bajtow
	call malloc; Wywołaj malloc
	
	test eax, eax		; Sprawdź czy udało się zaalokować
	jz problem_malloc	; Skok jeśli równe 0
	
	mov  [bufor], eax	; Pamiętaj adres początku tablicy w zmiennej bufor
	mov eax, 0x0		; Zeruj eax - poprawnie wykonana funkcja init
	ret					; return 0;
	
	problem_bound_val: 
				mov dword eax, -1	; Za duża rozmiar
				ret					; return -1
				
	problem_zero_val: 
				mov dword eax, -2	; rozmiar == 0 
				ret					; return -2
				
	problem_malloc : 
				mov dword eax, -3	; Niepoprawnie wykonany malloc
				ret					; return -3


; Implementacja producenta wg. wzorca:
; void producer(void)
; {
; 	int k = 0;
; 	int64_t porcja = 0;
; 	while(produce(&porcja) != 0)
; 	{
; 		proberen(&wolne);
;		BUFOR[k] = porcja;
;	 	verhogen(&zajete);
;		k++;
;		if(k >= rozmiar_bufora)
;			k = 0;
;	}
; }

; void producer(void);
; Poniżej notacja jak w powyższym kodzie w c
producer:
	xor eax,eax		; zeruj eax
	mov  [pamietaj], r13
	push r12		; k <-> r12 jest calle safe, wiec potem go przywroce
	mov  r12, 0x0	; k = 0
	
	petla : ; while(produce(&porcja)!=0)
		; początek petli	
		mov  edi, porcja	; przekaz do produce przez referencje
		call produce		; proberen(&wolne);
		test eax, eax		; czy zwrocilo 0
		jz koniec			; jeśli tak to koniec pętli, skok, jeśli zero
		
		mov  rdi, wolne		; przekaz semafor, przez referencje
		call proberen		; proberen(&wolne);
		
		mov rax, [bufor]	; przenies adres poczatku tablicy
		mov r8, r12			; r8 jest teraz licznikem w petli
		
		; Mnożenie w asm nie jest proste, a taki sposób przypadł mi do gustu :)
		mnozenie:
			cmp r8, 0			; czy licznik rowny 0
			je po_petli_prod	; skok, jeśli równe, czyli r8 == 0?
			add rax, 0x8		; Przesunięci o 8 bajtów - 64 bitowa liczba
			sub r8, 0x1			; zmniejsz licznik w petli
			jmp mnozenie		; powtorz petle
		
		po_petli_prod:	
		; w rax znajduje się adres k-tej komorki pamieci

		mov r13, [porcja]			; skopiuj wartosc porcji do r13
		; BUFOR[k] = porcja;
		mov qword [rax], r13	; pod ten adresy wpisz otrzymaną porcję
		
		
		mov  rdi, zajete	; przekaz do semafora, przez referencje
		call verhogen		; verhogen(&zajete);
		
		add qword r12, 0x1 ;k++;
		
		; rozmiar bufora danych

		; if(k > rozmiar_bufora)
		mov  eax, [rozmiar]
		mov [porownaj], r12
		cmp eax, [porownaj] ; rozmiar =?= k
		jne mniejsze		; skok, jeśli nie równe
		
		; Jeśli równe:
		xor qword r12, r12 ; k=0, przekrec bufor, k = 0
		
		mniejsze: 
			jmp petla	; kolejny obrót pętli
		koniec:	; wyjście z pętli
			mov r13, [pamietaj]; przywróć wartość r13
			pop r12	; Przywróć wartość r12
			ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Implementacja producenta wg. wzorca:
; void consumer(void)
; {
;	int k = 0;
;	int64_t porcja = 1;
;	do
;	{
;		proberen(&zajete);
;		porcja = BUFOR[k];
;		verhogen(&wolne);
;		if(k >= rozmiar_bufora)
;			k = 0;	
;	}while(consume(porcja) != 0);
;
; }

; void consumer(void)
consumer:
	xor eax,eax		;zeruj eax
	mov  [pamietaj], r13
	push r12		; k <-> r12 jest calle safe, wiec potem go przywroce
	mov  r12, 0x0	; k = 0
	petla_cons :	; do while(consume(porcja)!=0)
		; początek petli do while
		
		mov  rdi, zajete; przekaz semafor, przez referencje
		call proberen	; proberen(&zajete);

		mov rax, [bufor];przenies adres poczatku tablicy
		mov r8, r12		; r8 jest teraz licznikem w petli
		
		mnozenie_cons:
			cmp r8, 0			; czy licznik rowny 0
			je po_petli_cons	; skok, jeśli równe, czyli r8 == 0
			add rax, 0x8		; Przesunięci o 8 bajtów - 64 bitowa liczba
			sub r8, 0x1			; zmniejsz licznik w petli
			jmp mnozenie_cons	; powtórz petle
		
		po_petli_cons:				
		; w rax znajduje się adres k-tej komorki pamieci
		mov r13, [rax]			; Weź adres zapisany w rax
		; porcja = BUFOR[k];
		mov qword [porcja], r13	; do tego adresy wpisz porcje, 
		
		mov  rdi, wolne	;przekaz do semafora, przez referencje
		call verhogen	; verhogen(&wolne);
		
		add qword r12, 0x1; k++;
		
		
		mov  eax, [rozmiar]
		mov [porownaj], r12
		cmp eax, [porownaj]
		jne mniejsze_cons	;skok, jeśli nie równe
		
		xor qword r12, r12 		; k=0, przekrec bufor
		
		mniejsze_cons: 
				mov  edi, [porcja];przekaz do consume przez wartosc
				call consume ; consume(porcja)
				test eax, eax; czy zwrocilo 0
				jnz petla_cons; jeśli tak to koniec pętli
		mov r13, [pamietaj]; przywróć wartość r13
		pop r12; przywróć wartość r12
		ret


; Pomocnicza funkcja do debugowania, zwraca adres początku bufora
zwroc:
	xor eax,eax
	mov dword eax, [bufor]
	ret
	

	
	
	
	
	
	
	
	
	
	
	
	
	
